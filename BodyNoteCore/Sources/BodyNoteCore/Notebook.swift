import Foundation

public enum NotebookError: LocalizedError {
    case missingExercise, invalidSet, missingEntry, tooEarlyForFollowUp
    case invalidGoal, reflectionLocked, unsupportedFile
    case invalidRest, archivedDrill, invalidSkillTarget, skillSourceChanged
    case missingRoutineName, missingRoutine, restRoutine

    public var errorDescription: String? {
        switch self {
        case .missingExercise: return "운동 이름을 입력해 주세요."
        case .invalidSet: return "각 운동에 세트를 추가하고 양수인 수행량과 0 이상의 중량을 입력해 주세요."
        case .missingEntry: return "해당 기록을 찾을 수 없어요."
        case .tooEarlyForFollowUp: return "다음 날부터 몸 상태를 덧붙일 수 있어요."
        case .invalidGoal: return "목표 운동과 목표 일수를 확인해 주세요."
        case .reflectionLocked: return "재활·훈련을 6일 기록한 뒤 한 줄 회고를 작성해 주세요."
        case .unsupportedFile: return "이 파일을 열려면 운동일지를 최신 버전으로 업데이트해 주세요."
        case .invalidRest: return "세트 간 휴식은 0초 이상의 정수로 입력해 주세요."
        case .archivedDrill: return "이전 종목의 상세 수치는 원래 일지에서 확인할 수 있어요. 새 훈련은 세트로 기록해 주세요."
        case .invalidSkillTarget: return "이 기록의 단위와 범위에 맞는 목표를 입력해 주세요."
        case .skillSourceChanged: return "원래 운동 기록이 바뀌었어요. 기록판에서 현재 동작과 조건을 다시 선택해 주세요."
        case .missingRoutineName: return "루틴 이름을 입력해 주세요."
        case .missingRoutine: return "해당 루틴을 찾을 수 없어요."
        case .restRoutine: return "훈련 또는 재활 동작을 루틴으로 저장해 주세요."
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

public struct TrainingRoutine: Codable, Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let kind: EntryKind
    public let exercises: [Exercise]

    public func draft(using athlete: Athlete) -> JournalEntry {
        var entry = JournalEntry(kind: kind, exercises: exercises.map { $0.copied() })
        entry.recordedAthlete = athlete
        return entry
    }
}

public struct Notebook: Codable, Equatable {
    public private(set) var entries: [JournalEntry] = []
    public private(set) var pinnedNotes: [String: String] = [:]
    public private(set) var goals: [PersonalGoal] = []
    private var savedSkillGoals: [SkillGoal]?
    private var skillTargetDrafts: [SkillTargetDraft]?
    public var skillGoals: [SkillGoal] { (savedSkillGoals ?? []).filter { $0.condition.isSetGoal } }
    public private(set) var reflection = ""
    // Optional storage lets journals written before athlete selection open with the default kit.
    private var savedAthlete: Athlete?
    private var savedRoutines: [TrainingRoutine]?
    public private(set) var defaultRoutineID: UUID?
    public var lastReadTrainingDays: Int?
    var savedDrafts: [WorkoutDraft]?
    public var formInputs: [String: String]?
    public var recoveryNotifications: Bool?
    public private(set) var coachTurns: [CoachTurn]?

    public mutating func appendCoachTurn(_ turn: CoachTurn) {
        if coachTurns == nil { coachTurns = [] }
        coachTurns?.append(turn)
    }

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

    public var routines: [TrainingRoutine] { savedRoutines ?? [] }

    public var defaultRoutine: TrainingRoutine? {
        routines.first { $0.id == defaultRoutineID }
    }

    public func newTrainingDraft() -> JournalEntry {
        defaultRoutine?.draft(using: athlete) ?? athlete.newEntry()
    }

    public mutating func saveRoutine(name: String, kind: EntryKind, exercises: [Exercise],
                                     replacing id: UUID? = nil) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw NotebookError.missingRoutineName }
        guard kind != .rest else { throw NotebookError.restRoutine }
        let template = try validatedExercises(exercises.map { $0.copied() })
        let routine = TrainingRoutine(id: id ?? UUID(), name: name, kind: kind, exercises: template)
        var list = routines
        if let id {
            guard let index = list.firstIndex(where: { $0.id == id }) else { throw NotebookError.missingRoutine }
            list[index] = routine
        } else {
            if list.isEmpty { defaultRoutineID = routine.id }
            list.append(routine)
        }
        savedRoutines = list
    }

    public mutating func setDefaultRoutine(_ id: UUID?) throws {
        if let id, !routines.contains(where: { $0.id == id }) { throw NotebookError.missingRoutine }
        defaultRoutineID = id
    }

    public mutating func deleteRoutine(_ id: UUID) {
        savedRoutines?.removeAll { $0.id == id }
        savedDrafts?.removeAll { $0.purpose == .routine && $0.routineID == id }
        if defaultRoutineID == id { defaultRoutineID = nil }
    }

    private func validatedExercises(_ exercises: [Exercise], original: JournalEntry? = nil) throws -> [Exercise] {
        guard !exercises.isEmpty else { throw NotebookError.missingExercise }
        return try exercises.map { source in
            guard !source.key.isEmpty else { throw NotebookError.missingExercise }
            var exercise = source
            exercise.name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
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
            return exercise
        }
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
            entry.exercises = try validatedExercises(entry.exercises, original: original)
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
        removeDraft(entry.id)
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

    public func skillTargetInput(for reading: PerformanceReading) -> String? {
        skillTargetDrafts?.first { $0.matches(reading) }?.text
    }

    public mutating func rememberSkillTarget(_ text: String, for reading: PerformanceReading) throws {
        guard currentSkillReading(for: reading) != nil else { throw NotebookError.skillSourceChanged }
        if let index = skillTargetDrafts?.firstIndex(where: { $0.matches(reading) }) {
            skillTargetDrafts?[index].text = text
        } else {
            let draft = SkillTargetDraft(entryID: reading.entryID, exerciseID: reading.id,
                                        condition: reading.condition, text: text)
            skillTargetDrafts = (skillTargetDrafts ?? []) + [draft]
        }
    }

    public func legacySkillTarget(for reading: PerformanceReading) -> String? {
        formInputs?["skill-\(reading.id)"]
    }

    public mutating func reuseLegacySkillTarget(for reading: PerformanceReading) throws {
        guard let text = legacySkillTarget(for: reading) else { return }
        try rememberSkillTarget(text, for: reading)
        formInputs?["skill-\(reading.id)"] = nil
    }

    public mutating func addSkillGoal(from source: PerformanceReading, target: Int, start: JournalDay = JournalDay()) throws {
        guard let reading = currentSkillReading(for: source) else { throw NotebookError.skillSourceChanged }
        guard target > 0 else { throw NotebookError.invalidSkillTarget }
        skillTargetDrafts?.removeAll { $0.matches(reading) }
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
