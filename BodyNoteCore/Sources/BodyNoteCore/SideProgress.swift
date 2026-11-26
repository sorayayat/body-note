import Foundation

public struct SideProgressCondition: Hashable {
    fileprivate let name: String
    fileprivate let equipment: String
    public let weightKg: Double?
    public let unit: ExerciseUnit
}

public struct SideReading: Identifiable {
    public var id: UUID { entryID }
    public let entryID: UUID
    public let day: JournalDay
    public let amount: Int
}

public struct SideHistory {
    public private(set) var previous: SideReading?
    public private(set) var latest: SideReading?

    public var change: Int? {
        guard let previous, let latest else { return nil }
        return latest.amount - previous.amount
    }

    // Entries, exercises and sets arrive newest first. Each journal contributes at most once per side.
    fileprivate mutating func include(_ reading: SideReading) {
        if latest == nil {
            latest = reading
        } else if previous == nil && latest?.entryID != reading.entryID {
            previous = reading
        }
    }
}

public struct SideProgressCard: Identifiable {
    public let id: SideProgressCondition
    public let name: String
    public let equipment: String
    public fileprivate(set) var left = SideHistory()
    public fileprivate(set) var right = SideHistory()
}

public extension Notebook {
    func sideProgress(for exerciseName: String? = nil) -> [SideProgressCard] {
        let target = exerciseName.map(Exercise.key(for:))
        var cards: [SideProgressCondition: SideProgressCard] = [:]
        var order: [SideProgressCondition] = []

        for entry in newestFirst where entry.kind != .rest {
            for exercise in entry.exercises.reversed() where exercise.drill == nil {
                let nameKey = exercise.key
                guard !nameKey.isEmpty, target == nil || target == nameKey else { continue }
                let equipmentKey = Exercise.key(for: exercise.equipment)
                for set in exercise.sets.reversed() where set.side == .left || set.side == .right {
                    guard set.amount > 0, set.weightKg.map({ $0.isFinite && $0 >= 0 }) ?? true else { continue }
                    let condition = SideProgressCondition(name: nameKey, equipment: equipmentKey,
                                                          weightKg: set.weightKg, unit: exercise.unit)
                    if cards[condition] == nil {
                        order.append(condition)
                        cards[condition] = SideProgressCard(id: condition, name: exercise.name,
                                                            equipment: exercise.equipment.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    let reading = SideReading(entryID: entry.id, day: entry.day, amount: set.amount)
                    if set.side == .left {
                        cards[condition]?.left.include(reading)
                    } else {
                        cards[condition]?.right.include(reading)
                    }
                }
            }
        }
        return order.compactMap { cards[$0] }
    }
}
