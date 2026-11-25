import Foundation

public struct JournalDay: Codable, Hashable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(_ date: Date = .now, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        (year, month, day) = (parts.year!, parts.month!, parts.day!)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public var label: String { "\(year)년 \(month)월 \(day)일" }
    public var shortLabel: String { "\(month)월 \(day)일" }
}

public enum EntryKind: String, Codable, CaseIterable {
    case training, rehab, rest

    public var title: String {
        switch self {
        case .training: return "훈련"
        case .rehab: return "재활"
        case .rest: return "휴식"
        }
    }
}

public enum ExerciseUnit: String, Codable, CaseIterable {
    case reps, seconds, minutes, meters

    public var title: String {
        switch self {
        case .reps: return "회"
        case .seconds: return "초"
        case .minutes: return "분"
        case .meters: return "m"
        }
    }
}

public enum BodySide: String, Codable, CaseIterable {
    case unspecified, left, right, both

    public var title: String {
        switch self {
        case .unspecified: return "구분 없음"
        case .left: return "왼쪽"
        case .right: return "오른쪽"
        case .both: return "양쪽"
        }
    }
}

public struct TrainingSet: Identifiable, Codable, Equatable {
    public var id = UUID()
    public var amount: Int
    public var weightKg: Double?
    public var side: BodySide

    public init(amount: Int = 10, weightKg: Double? = nil, side: BodySide = .unspecified) {
        self.amount = amount
        self.weightKg = weightKg
        self.side = side
    }

    public func copied() -> Self {
        var copy = self
        copy.id = UUID()
        return copy
    }
}

public struct Exercise: Identifiable, Codable, Equatable {
    public var id = UUID()
    public var name: String
    public var unit: ExerciseUnit = .reps
    public var equipment = ""
    public var sets: [TrainingSet]
    public var note = ""
    public var restSeconds: Int?
    public var drill: SportDrill?

    public init(name: String = "", sets: [TrainingSet] = [TrainingSet()]) {
        self.name = name
        self.sets = sets
    }

    public static func key(for name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
    }

    public var key: String { Self.key(for: name) }

    func copied() -> Self {
        var copy = self
        copy.id = UUID()
        if let drill {
            copy.unit = drill.sport == .running ? .meters : .reps
            let amount = drill.sport == .running ? drill.meters : drill.attempts
            copy.sets = [TrainingSet(amount: amount ?? 1)]
            copy.drill = nil
        } else {
            copy.sets = sets.map { $0.copied() }
        }
        copy.note = ""
        return copy
    }
}

public struct JournalEntry: Identifiable, Codable, Equatable {
    public let id: UUID
    public internal(set) var recordedAt: Date
    public internal(set) var day: JournalDay
    public var kind: EntryKind
    // Older journals stored a sport before entries had their own character and outfit.
    public var sport: TrainingSport?
    public var recordedAthlete: Athlete?
    public var exercises: [Exercise]
    public var before = ""
    public var after = ""
    public var effort = ""
    public var note = ""
    public var followUp = ""

    public init(kind: EntryKind = .training, sport: TrainingSport? = nil, exercises: [Exercise] = [Exercise()],
                date: Date = .now, timeZone: TimeZone = .current) {
        id = UUID()
        recordedAt = date
        day = JournalDay(date, timeZone: timeZone)
        self.kind = kind
        self.sport = kind == .rest ? nil : sport
        self.exercises = kind == .rest ? [] : exercises
    }

    public var title: String {
        guard kind != .rest, let first = exercises.first else { return "휴식 기록" }
        return exercises.count == 1 ? first.name : "\(first.name) 외 \(exercises.count - 1)개"
    }

    public func appearance(using fallback: Athlete) -> Athlete {
        if let recordedAthlete { return recordedAthlete }
        var result = fallback
        if let sport { result.sport = sport }
        return result
    }

    public func draftForToday(only exercise: Exercise? = nil, using athlete: Athlete? = nil) -> Self {
        let source = exercise.map { [$0] } ?? exercises
        var draft = Self(kind: kind, exercises: source.map { $0.copied() })
        if kind != .rest {
            var next = athlete ?? recordedAthlete ?? Athlete()
            next.sport = appearance(using: next).sport
            draft.recordedAthlete = next
        }
        return draft
    }
}
