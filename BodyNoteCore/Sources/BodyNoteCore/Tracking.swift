import Foundation

public enum BodySignal: String, Codable, CaseIterable {
    case comfortable, discomfort, stopped, worsening

    public var title: String {
        switch self {
        case .comfortable: return "특이사항 없음"
        case .discomfort: return "불편함이 있었어요"
        case .stopped: return "통증으로 중단했어요"
        case .worsening: return "통증이 심해졌어요"
        }
    }

    public var guidance: String? {
        switch self {
        case .comfortable: return nil
        case .discomfort: return "어떤 동작에서 불편했는지 메모하고 다음 운동 전에 다시 확인해요."
        case .stopped, .worsening:
            return "아픈 동작은 멈추세요. 통증이 심해지거나 체중을 싣기 어렵다면 의료진에게 진료를 받으세요."
        }
    }
}

public struct ActivityDay: Identifiable {
    public let day: JournalDay
    public var id: JournalDay { day }
    public var sessions = 0
    public var sets = 0
    public var rested = false
}

public struct RecoveryCue: Equatable {
    public enum Kind: String { case discomfort, rest }
    public let kind: Kind
    public let title: String
    public let detail: String
    public let entryID: UUID
    public let day: JournalDay

    /// One private follow-up the morning after the originating record, never a repeating alarm.
    public func reminderDate(after now: Date, zone: TimeZone = .current) -> Date? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let parts = DateComponents(year: day.year, month: day.month, day: day.day, hour: 9)
        guard let start = cal.date(from: parts), let next = cal.date(byAdding: .day, value: 1, to: start),
              next > now else { return nil }
        return next
    }
}

public struct TrackingWeek {
    public let days: [ActivityDay]
    public let previousActiveDays: Int
    public let cues: [RecoveryCue]
    public var activeDays: Int { days.filter { $0.sessions > 0 }.count }
    public var sessions: Int { days.reduce(0) { $0 + $1.sessions } }
    public var sets: Int { days.reduce(0) { $0 + $1.sets } }
}

extension Notebook {
    public func tracking(at now: Date = .now, zone: TimeZone = .current) -> TrackingWeek {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let dates = (-13...0).compactMap { cal.date(byAdding: .day, value: $0, to: now) }
            .map { JournalDay($0, timeZone: zone) }
        let week = dates.suffix(7)
        let grouped = Dictionary(grouping: entries.filter { dates.contains($0.day) }, by: \.day)
        let days = week.map { day -> ActivityDay in
            let records = grouped[day] ?? []
            let sessions = records.filter { $0.kind != .rest }
            return ActivityDay(day: day, sessions: sessions.count,
                               sets: sessions.flatMap(\.exercises).filter { $0.drill == nil }.reduce(0) { $0 + $1.sets.count },
                               rested: records.contains { $0.kind == .rest })
        }
        let recent = newestFirst.filter { week.contains($0.day) }
        var cues: [RecoveryCue] = []
        if let checked = recent.first(where: { $0.bodySignal != nil }),
           let signal = checked.bodySignal, let detail = signal.guidance {
            cues.append(RecoveryCue(kind: .discomfort, title: signal.title, detail: detail, entryID: checked.id, day: checked.day))
        }
        if let last = recent.first, last.kind != .rest {
            let activeDates = Set(entries.lazy.filter { $0.kind != .rest }.map(\.day))
            var cursor = now
            if let today = days.last, today.sessions == 0 && !today.rested {
                cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            }
            var streak = 0
            while activeDates.contains(JournalDay(cursor, timeZone: zone)),
                  let prior = cal.date(byAdding: .day, value: -1, to: cursor) {
                streak += 1
                cursor = prior
            }
            if streak >= 3 {
                cues.append(RecoveryCue(kind: .rest, title: "연속 \(streak)일 운동했어요",
                                        detail: "오늘의 피로를 살펴보고 쉬는 날을 계획해 볼까요?",
                                        entryID: last.id, day: last.day))
            }
        }
        let previous = dates.prefix(7).filter { day in grouped[day]?.contains { $0.kind != .rest } == true }.count
        return TrackingWeek(days: days, previousActiveDays: previous, cues: cues)
    }
}
