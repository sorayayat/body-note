import Foundation

// Read-only fields from the previous sport-specific journal format.
public struct SportDrill: Equatable, Codable {
    public let sport: TrainingSport
    public let reference: String
    public let meters: Int?
    public let attempts: Int?
    public let elapsed: String
    public let averageBPM: Int?
    public let talk: String?
    public let hits: Int?
    public let assisted: Int?

    public var summary: String {
        var parts = [reference]
        if let meters { parts.append("\(meters) m") }
        switch sport {
        case .running:
            parts.append(elapsed)
            if let averageBPM { parts.append("평균 \(averageBPM) bpm") }
            if let talk { parts.append(talk) }
        case .fieldHockey:
            if let hits, let attempts { parts.append("\(attempts)회 중 \(hits)회 성공") }
        case .basic:
            if let assisted, let attempts { parts.append("\(attempts)회 중 손 짚기 \(assisted)회") }
        default: break
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

private struct SetCondition: Codable, Hashable {
    let weight: Double?
    let side: BodySide
    let earlierReps: Int?

    var label: String {
        var text = weight.map { "\($0.formatted()) kg" } ?? "맨몸"
        if side != .unspecified { text += " \(side.title)" }
        if let earlierReps { text += " × \(earlierReps)" }
        return text
    }
}

public struct PerformanceCondition: Codable, Hashable {
    // Version 1 identifies set goals with "weightTraining". The entry's skin is independent.
    private let sport: TrainingSport
    private let exerciseKey: String
    private let equipment: String
    private let reference: String
    private let meters: Int?
    private let attempts: Int?
    private let rest: Int?
    private let sets: [SetCondition]

    fileprivate init(exercise: Exercise) {
        sport = .weightTraining
        exerciseKey = exercise.key
        equipment = Exercise.key(for: exercise.equipment)
        reference = ""
        meters = nil
        attempts = nil
        rest = exercise.sets.count > 1 ? exercise.restSeconds : nil
        sets = exercise.sets.enumerated().map { index, set in
            SetCondition(weight: set.weightKg, side: set.side, earlierReps: index < exercise.sets.count - 1 ? set.amount : nil)
        }
    }

    var isSetGoal: Bool { sport == .weightTraining && !sets.isEmpty }

    public var label: String {
        var parts = [equipment, sets.map(\.label).joined(separator: " / ")].filter { !$0.isEmpty }
        if let rest { parts.append("휴식 \(rest)초") }
        return parts.joined(separator: " · ")
    }
}

public struct PerformanceReading: Identifiable {
    public let id: UUID
    public let entryID: UUID
    public let day: JournalDay
    public let name: String
    public let recordedAthlete: Athlete?
    public let condition: PerformanceCondition
    public let value: Int

    fileprivate init?(entry: JournalEntry, exercise: Exercise) {
        guard entry.kind != .rest, exercise.drill == nil, exercise.unit == .reps,
              let last = exercise.sets.last, exercise.sets.count == 1 || exercise.restSeconds != nil else { return nil }
        value = last.amount
        id = exercise.id
        entryID = entry.id
        day = entry.day
        name = exercise.name
        recordedAthlete = entry.recordedAthlete
        condition = PerformanceCondition(exercise: exercise)
    }
}

public struct GrowthCard: Identifiable {
    public var id: PerformanceCondition { current.condition }
    public let current: PerformanceReading
    public let previous: PerformanceReading?

    public var feedback: String {
        guard let previous else { return "같은 조건의 다음 훈련을 확정하면 변화를 볼 수 있어요." }
        let delta = current.value - previous.value
        if delta == 0 { return "지난번과 같은 기록이에요." }
        return "마지막 세트에서 \(abs(delta))회 \(delta > 0 ? "더" : "적게") 수행했어요."
    }
}

public struct SkillGoal: Identifiable, Codable, Equatable {
    public static let requiredSessions = 3
    public let id: UUID
    public let name: String
    public let condition: PerformanceCondition
    public let target: Int
    public let start: JournalDay
    // Preserve archived running goals when the notebook is saved.
    var referenceBPM: Int?
    var referenceTalk: String?
    public var threshold: String { "마지막 세트 \(target)회 이상" }
}

public extension Notebook {
    var earnedSkillGoalIDs: Set<UUID> {
        Set(skillGoals.filter { entriesContributing(to: $0).count == SkillGoal.requiredSessions }.map(\.id))
    }

    var growthBoard: [GrowthCard] {
        let readings = newestFirst.flatMap { entry in
            entry.exercises.reversed().compactMap { PerformanceReading(entry: entry, exercise: $0) }
        }
        let groups = Dictionary(grouping: readings, by: \.condition)
        var seen = Set<PerformanceCondition>()
        return readings.compactMap { current in
            guard seen.insert(current.condition).inserted else { return nil }
            let previous = groups[current.condition]?.first { $0.entryID != current.entryID }
            return GrowthCard(current: current, previous: previous)
        }
    }

    func entriesContributing(to goal: SkillGoal) -> [JournalEntry] {
        var matches: [JournalEntry] = []
        for entry in newestFirst.reversed() where entry.day >= goal.start {
            let qualifies = entry.exercises.contains { exercise in
                guard let reading = PerformanceReading(entry: entry, exercise: exercise) else { return false }
                return reading.condition == goal.condition && reading.value >= goal.target
            }
            if qualifies {
                matches.append(entry)
                if matches.count == SkillGoal.requiredSessions { break }
            }
        }
        return matches
    }
}
