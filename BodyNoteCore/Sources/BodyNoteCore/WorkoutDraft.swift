import Foundation

public struct WorkoutDraft: Codable, Identifiable, Equatable {
    public enum Purpose: String, Codable { case journal, routine }
    public let purpose: Purpose
    public var entry: JournalEntry
    public var name: String
    public var routineID: UUID?
    public var parentID: UUID?
    // Keep even unfinished numbers (e.g. an empty rep count or "12.") exactly as typed.
    public var numbers: [String: String] = [:]
    public var id: UUID { entry.id }

    public init(_ entry: JournalEntry, purpose: Purpose = .journal, name: String = "",
                routineID: UUID? = nil, parentID: UUID? = nil) {
        self.entry = entry
        self.purpose = purpose
        self.name = name
        self.routineID = routineID
        self.parentID = parentID
    }

    public var label: String {
        if purpose == .routine { return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "새 루틴" : name }
        guard entry.kind != .rest, let first = entry.exercises.first(where: { !$0.key.isEmpty }) else {
            return "\(entry.kind.title) 기록"
        }
        return entry.exercises.count > 1 ? "\(first.name) 외 \(entry.exercises.count - 1)개" : first.name
    }

    public var preview: String? {
        var parts: [String] = []
        let exercise = entry.exercises.first { exercise in
            !exercise.key.isEmpty || exercise.sets.contains { numbers["amount-\($0.id)"] != nil || numbers["weight-\($0.id)"] != nil }
        }
        if entry.kind != .rest, let exercise, let set = exercise.sets.first {
            let weight = numbers["weight-\(set.id)"] ?? set.weightKg?.formatted() ?? ""
            let amount = numbers["amount-\(set.id)"] ?? String(set.amount)
            if !weight.isEmpty { parts.append(weight + " kg") }
            if !amount.isEmpty { parts.append(amount + exercise.unit.title) }
            if !parts.isEmpty { parts[0] = "1세트 " + parts[0] }
        }
        let memo = [entry.note, entry.before, entry.after, exercise?.note ?? ""].lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        if let memo { parts.append(memo) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    public func resolvedEntry() throws -> JournalEntry {
        var result = entry
        guard result.kind != .rest else { return result }
        for e in result.exercises.indices where result.exercises[e].drill == nil {
            var exercise = result.exercises[e]
            if exercise.unit != .reps || exercise.sets.count < 2 {
                exercise.restSeconds = nil
            } else if let text = numbers["rest-\(exercise.id)"] {
                let rest = Int(text)
                guard text.isEmpty || (rest.map { $0 >= 0 } == true) else { throw NotebookError.invalidRest }
                exercise.restSeconds = rest
            }
            for s in exercise.sets.indices {
                let id = exercise.sets[s].id
                if let text = numbers["amount-\(id)"] {
                    guard let value = Int(text), value > 0 else { throw NotebookError.invalidSet }
                    exercise.sets[s].amount = value
                }
                if let text = numbers["weight-\(id)"] {
                    let value = Double(text.replacingOccurrences(of: ",", with: "."))
                    guard text.isEmpty || (value.map { $0.isFinite && $0 >= 0 } == true) else {
                        throw NotebookError.invalidSet
                    }
                    exercise.sets[s].weightKg = value
                }
            }
            result.exercises[e] = exercise
        }
        return result
    }
}

extension Notebook {
    public var drafts: [WorkoutDraft] { savedDrafts ?? [] }

    public mutating func keepDraft(_ draft: WorkoutDraft) {
        var list = drafts.filter { $0.id != draft.id }
        list.insert(draft, at: 0)
        savedDrafts = list
    }

    public mutating func removeDraft(_ id: UUID) { savedDrafts?.removeAll { $0.id == id } }

    public mutating func finishRoutine(_ draft: WorkoutDraft) throws {
        let entry = try draft.resolvedEntry()
        try saveRoutine(name: draft.name, kind: entry.kind, exercises: entry.exercises, replacing: draft.routineID)
        removeDraft(draft.id)
    }
}
