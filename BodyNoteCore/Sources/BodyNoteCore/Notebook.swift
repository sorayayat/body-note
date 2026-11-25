import Foundation

public enum NotebookError: LocalizedError {
    case missingExercise, invalidSet, missingEntry, tooEarlyForFollowUp
    case invalidGoal, reflectionLocked, unsupportedFile
    case invalidRest, archivedDrill, invalidSkillTarget

    public var errorDescription: String? {
        switch self {
        case .missingExercise: return "운동 이름을 입력해 주세요."
        case .invalidSet: return "각 운동에 세트를 추가하고 양수인 수행량과 0 이상의 중량을 입력해 주세요."
        case .missingEntry: return "해당 기록을 찾을 수 없어요."
        case .tooEarlyForFollowUp: return "다음 날부터 몸 상태를 덧붙일 수 있어요."
        case .invalidGoal: return "목표 운동과 목표 일수를 확인해 주세요."
        case .reflectionLocked: return "재활·훈련을 6일 기록한 뒤 한 줄 회고를 작성해 주세요."
        case .unsupportedFile: return "이 일지는 더 새로운 버전의 Body Note에서 저장했어요."
        case .invalidRest: return "세트 간 휴식은 0초 이상의 정수로 입력해 주세요."
        case .archivedDrill: return "이전 종목의 상세 수치는 원래 일지에서 확인할 수 있어요. 새 훈련은 세트로 기록해 주세요."
        case .invalidSkillTarget: return "이 기록의 단위와 범위에 맞는 목표를 입력해 주세요."
        }
    }
}

public struct PersonalGoal: Codable, Identifiable, Equatable {
    public let id: UUID
    public let exerciseName: String
    public let targetDays: Int
    public let start: JournalDay

    public var title: String { "\(exerciseName) \(targetDays)일 기록" }
}

public struct Notebook: Codable, Equatable {
    public private(set) var entries: [JournalEntry] = []
    public private(set) var pinnedNotes: [String: String] = [:]
    public private(set) var goals: [PersonalGoal] = []
    private var savedSkillGoals: [SkillGoal]?
    public var skillGoals: [SkillGoal] { (savedSkillGoals ?? []).filter { $0.condition.isSetGoal } }
    public private(set) var reflection = ""
    // Optional storage lets journals written before athlete selection open with the default kit.
    private var savedAthlete: Athlete?
    public var lastReadTrainingDays: Int?

    public var athlete: Athlete {
        get { savedAthlete ?? Athlete() }
        set { savedAthlete = newValue }
    }

    public init() {}

    public var newestFirst: [JournalEntry] { entries.reversed().sorted { $0.recordedAt > $1.recordedAt } }

    public var fieldAthlete: Athlete {
        newestFirst.first { $0.kind != .rest }?.appearance(using: athlete) ?? athlete
    }

    mutating func restoreRecordAppearances() {
        let fallback = athlete
        for index in entries.indices where entries[index].kind != .rest && entries[index].recordedAthlete == nil {
            entries[index].recordedAthlete = entries[index].appearance(using: fallback)
        }
    }

    public var exerciseNames: [String] {
        var seen = Set<String>()
        let names = newestFirst.flatMap(\.exercises).filter { seen.insert($0.key).inserted }.map(\.name)
        return names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    public func history(for name: String) -> [JournalEntry] {
        let key = Exercise.key(for: name)
        return newestFirst.filter { $0.exercises.contains { $0.key == key } }
    }

    // A draft only enters the notebook here. An existing ID edits its original local day.
    public mutating func confirm(_ draft: JournalEntry, at now: Date = .now,
                                 timeZone: TimeZone = .current) throws {
        var entry = draft
        let existingIndex = entries.firstIndex { $0.id == entry.id }
        let original = existingIndex.map { entries[$0] }
        if entry.kind == .rest {
            entry.exercises = []
            entry.sport = nil
            entry.recordedAthlete = nil
            entry.effort = ""
            entry.after = ""
        } else {
            if entry.recordedAthlete == nil {
                entry.recordedAthlete = original?.recordedAthlete ?? entry.appearance(using: athlete)
            }
            guard !entry.exercises.isEmpty else { throw NotebookError.missingExercise }
            for index in entry.exercises.indices {
                let exercise = entry.exercises[index]
                guard !exercise.key.isEmpty else { throw NotebookError.missingExercise }
                if let drill = exercise.drill {
                    guard original?.exercises.contains(where: { $0.id == exercise.id && $0.drill == drill }) == true else {
                        throw NotebookError.archivedDrill
                    }
                } else {
                    guard !exercise.sets.isEmpty, exercise.sets.allSatisfy({ set in
                        set.amount > 0 && (set.weightKg.map { $0.isFinite && $0 >= 0 } ?? true)
                    }) else { throw NotebookError.invalidSet }
                    if let rest = exercise.restSeconds, rest < 0 { throw NotebookError.invalidRest }
                }
                entry.exercises[index].name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if let index = existingIndex {
            entry.recordedAt = entries[index].recordedAt
            entry.day = entries[index].day
            entry.followUp = entries[index].followUp
            entries[index] = entry
        } else {
            if entry.sport?.isAvailable == false { entry.sport = nil }
            entry.recordedAt = now
            entry.day = JournalDay(now, timeZone: timeZone)
            entries.append(entry)
        }
    }

    public mutating func pin(_ text: String, for name: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        pinnedNotes[Exercise.key(for: name)] = value.isEmpty ? nil : value
    }

    public mutating func setFollowUp(_ text: String, for id: UUID, today: JournalDay = JournalDay()) throws {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { throw NotebookError.missingEntry }
        guard entries[index].day < today else { throw NotebookError.tooEarlyForFollowUp }
        entries[index].followUp = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var activeDayCount: Int { Set(entries.filter { $0.kind != .rest }.map(\.day)).count }
    public var xp: Int { activeDayCount * 10 }
    public static let xpPerLevel = 100
    public var level: Int { 1 + xp / Self.xpPerLevel }
    public var levelXP: Int { xp % Self.xpPerLevel }
    public var remainingXP: Int { Self.xpPerLevel - levelXP }
    public var hasMatArea: Bool { activeDayCount >= 6 && !reflection.isEmpty }
    public var hasTrainingNews: Bool { lastReadTrainingDays != activeDayCount }

    public mutating func saveReflection(_ text: String) throws {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard activeDayCount >= 6, !value.isEmpty else { throw NotebookError.reflectionLocked }
        reflection = value
    }

    public mutating func addGoal(exerciseName: String, targetDays: Int, start: JournalDay = JournalDay()) throws {
        let name = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, (1...30).contains(targetDays) else { throw NotebookError.invalidGoal }
        goals.append(PersonalGoal(id: UUID(), exerciseName: name, targetDays: targetDays, start: start))
    }

    public mutating func addSkillGoal(from reading: PerformanceReading, target: Int, start: JournalDay = JournalDay()) throws {
        guard target > 0 else { throw NotebookError.invalidSkillTarget }
        if skillGoals.contains(where: { $0.condition == reading.condition && $0.target == target }) { return }
        let goal = SkillGoal(id: UUID(), name: reading.name, condition: reading.condition, target: target, start: start)
        savedSkillGoals = (savedSkillGoals ?? []) + [goal]
    }

    // The flag links back to the first qualifying entry on each distinct day.
    public func entriesContributing(to goal: PersonalGoal) -> [JournalEntry] {
        var days = Set<JournalDay>()
        let matching = history(for: goal.exerciseName).reversed().filter {
            $0.day >= goal.start && days.insert($0.day).inserted
        }
        return Array(matching.prefix(goal.targetDays))
    }
}
