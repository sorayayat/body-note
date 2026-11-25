import Foundation
import XCTest
@testable import BodyNoteCore

final class PerformanceTests: XCTestCase {
    private let zone = TimeZone(secondsFromGMT: 0)!
    private let start = Date(timeIntervalSince1970: 1_735_689_600)

    private func session(_ animal: Animal, _ skin: TrainingSport, reps: Int = 10) -> JournalEntry {
        var athlete = Athlete()
        athlete.animal = animal
        athlete.sport = skin
        var draft = athlete.newEntry()
        draft.exercises = [Exercise(name: "스쿼트", sets: [TrainingSet(amount: reps, weightKg: 30)])]
        return draft
    }

    private func confirm(_ entry: JournalEntry, _ book: inout Notebook, seconds: Int) throws {
        try book.confirm(entry, at: start.addingTimeInterval(Double(seconds)), timeZone: zone)
    }

    func testStrengthUsesEarlierRepsAllWeightsSidesEquipmentAndRest() throws {
        func squat(_ reps: [Int], rest: Int? = 60) -> JournalEntry {
            var movement = Exercise(name: "스쿼트", sets: reps.map { TrainingSet(amount: $0, weightKg: 30) })
            movement.restSeconds = rest
            return JournalEntry(sport: .weightTraining, exercises: [movement])
        }
        var book = Notebook()
        try confirm(squat([10, 8, 6]), &book, seconds: 1)
        try confirm(squat([10, 7, 12]), &book, seconds: 2)
        try confirm(squat([10, 8, 12], rest: 90), &book, seconds: 3)
        var load = squat([10, 8, 12])
        load.exercises[0].sets[1].weightKg = 32.5
        try confirm(load, &book, seconds: 4)
        var side = squat([10, 8, 12])
        side.exercises[0].sets[0].side = .right
        try confirm(side, &book, seconds: 5)
        var gear = squat([10, 8, 12])
        gear.exercises[0].equipment = "스미스 머신"
        try confirm(gear, &book, seconds: 6)
        try confirm(squat([10, 8, 12], rest: nil), &book, seconds: 7)
        try confirm(squat([10, 8, 9]), &book, seconds: 8)
        let board = book.growthBoard
        XCTAssertEqual(board.count, 6)
        XCTAssertEqual(board.first?.previous?.value, 6)
        XCTAssertEqual(board.first?.current.value, 9)
        XCTAssertEqual(board.first?.feedback, "마지막 세트에서 3회 더 수행했어요.")
        XCTAssertEqual(book.xp, 10)
    }

    func testFieldUsesLatestConfirmedWorkoutAndIgnoresRestAndOlderEdits() throws {
        var book = Notebook()
        book.athlete.animal = .raccoon
        book.athlete.sport = .running
        XCTAssertEqual(book.fieldAthlete, book.athlete)
        let first = session(.rabbit, .fieldHockey)
        var last = session(.dog, .basic)
        last.kind = .rehab
        try confirm(first, &book, seconds: 0)
        try confirm(last, &book, seconds: 1)
        var wrong = session(.cat, .weightTraining)
        wrong.exercises = []
        XCTAssertThrowsError(try confirm(wrong, &book, seconds: 2))
        book.athlete.sport = .weightTraining
        try confirm(JournalEntry(kind: .rest), &book, seconds: 86_400)
        var edited = first
        edited.recordedAthlete?.sport = .running
        try confirm(edited, &book, seconds: 90_000)
        XCTAssertEqual(book.fieldAthlete, last.recordedAthlete)
        XCTAssertEqual(book.entries[0].recordedAthlete?.sport, .running)
        XCTAssertNil(book.entries.last?.recordedAthlete)
        XCTAssertEqual(book.xp, 10)
        var rest = last
        rest.kind = .rest
        try confirm(rest, &book, seconds: 95_000)
        XCTAssertEqual(book.fieldAthlete, edited.recordedAthlete)
        let restored = try JSONDecoder().decode(Notebook.self, from: JSONEncoder().encode(book))
        XCTAssertEqual(restored.fieldAthlete, book.fieldAthlete)
        XCTAssertEqual(restored.athlete, book.athlete)
    }

    func testCopyUsesCurrentAnimalAndRecordedSkinWithoutChangingOriginal() throws {
        var book = Notebook()
        try confirm(session(.rabbit, .fieldHockey), &book, seconds: 0)
        let old = try XCTUnwrap(book.entries.first)
        book.athlete.animal = .dog
        book.athlete.sport = .basic
        var copy = old.draftForToday(only: old.exercises[0], using: book.athlete)
        XCTAssertEqual(copy.recordedAthlete?.animal, .dog)
        XCTAssertEqual(copy.recordedAthlete?.sport, .fieldHockey)
        XCTAssertNil(copy.sport)
        XCTAssertEqual(book.fieldAthlete, old.recordedAthlete)
        copy.recordedAthlete?.sport = .weightTraining
        try confirm(copy, &book, seconds: 1)
        XCTAssertEqual(book.entries[0], old)
        XCTAssertEqual(book.fieldAthlete, copy.recordedAthlete)
        XCTAssertEqual(book.athlete.sport, .basic)
    }

    func testSameSetsAcrossAllSkinsShareComparisonsAndBadgeProgress() throws {
        var book = Notebook()
        let baseline = session(.cat, .running, reps: 7)
        try confirm(baseline, &book, seconds: 0)
        let startDay = JournalDay(start, timeZone: zone)
        let reading = try XCTUnwrap(book.growthBoard.first?.current)
        try book.addSkillGoal(from: reading, target: 10, start: startDay)
        XCTAssertThrowsError(try book.addSkillGoal(from: reading, target: 0, start: startDay))
        let first = session(.rabbit, .fieldHockey)
        try confirm(first, &book, seconds: 1)
        var second = session(.dog, .basic)
        second.kind = .rehab
        second.exercises += session(.dog, .basic, reps: 12).exercises
        try confirm(second, &book, seconds: 2)
        let third = session(.raccoon, .weightTraining, reps: 13)
        try confirm(third, &book, seconds: 3)
        let card = try XCTUnwrap(book.growthBoard.first)
        XCTAssertEqual(book.growthBoard.count, 1)
        XCTAssertEqual(card.previous?.value, 12)
        XCTAssertEqual(card.current.value, 13)
        try book.addSkillGoal(from: card.current, target: 10, start: startDay)
        XCTAssertEqual(book.skillGoals.count, 1)
        let goal = try XCTUnwrap(book.skillGoals.first)
        XCTAssertEqual(book.entriesContributing(to: goal).map(\.id), [first.id, second.id, third.id])
        XCTAssertEqual(book.earnedSkillGoalIDs, [goal.id])
        XCTAssertEqual(book.xp, 10)
        var edit = first
        edit.exercises[0].sets[0].amount = 8
        try confirm(edit, &book, seconds: 99_000)
        XCTAssertTrue(book.earnedSkillGoalIDs.isEmpty)
    }

    func testOldDrillsAndGoalsRoundTripWhileCopiesBecomeOrdinarySets() throws {
        let file = NotebookFile(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { try? FileManager.default.removeItem(at: file.url) }
        let day = ["year": 2025, "month": 1, "day": 1]
        let observations: [[String: Any]] = [
            ["sport": "running", "reference": "강변", "meters": 3000, "elapsed": "20:20", "averageBPM": 150, "talk": "편하게 말함"],
            ["sport": "fieldHockey", "reference": "작은 골대", "meters": 5, "attempts": 20, "hits": 16, "elapsed": ""],
            ["sport": "basic", "reference": "의자", "attempts": 5, "assisted": 0, "elapsed": ""]
        ]
        let entries: [[String: Any]] = observations.enumerated().map { index, observation in
            let exercise: [String: Any] = ["id": UUID().uuidString, "name": "이전 운동", "unit": "reps",
                "equipment": "", "sets": [], "note": "", "drill": observation]
            return ["id": UUID().uuidString, "recordedAt": index, "day": day, "sport": observation["sport"]!,
                    "kind": index == 2 ? "rehab" : "training", "exercises": [exercise],
                    "before": "", "after": "", "effort": "", "note": "", "followUp": ""]
        }
        let condition: [String: Any] = ["sport": "running", "exerciseKey": "이전 운동", "equipment": "",
                                        "reference": "강변", "meters": 3000, "sets": []]
        let archived: [String: Any] = ["id": UUID().uuidString, "name": "강변", "condition": condition, "target": 1220,
                                       "start": day, "referenceBPM": 150]
        let json: [String: Any] = ["entries": entries, "goals": [], "pinnedNotes": [:], "reflection": "",
            "savedSkillGoals": [archived], "savedAthlete": ["animal": "rabbit", "sport": "running"]]
        try JSONSerialization.data(withJSONObject: ["version": 1, "notebook": json]).write(to: file.url)
        var book = try file.load()
        let originals = book.entries
        XCTAssertTrue(book.skillGoals.isEmpty)
        XCTAssertTrue(book.growthBoard.isEmpty)
        XCTAssertEqual(book.fieldAthlete.sport, .basic)
        book.athlete.animal = .dog
        for (index, original) in originals.enumerated() {
            XCTAssertEqual(original.recordedAthlete?.animal, .rabbit)
            XCTAssertEqual(original.recordedAthlete?.sport, original.sport)
            var edited = original
            edited.note = "메모"
            edited.recordedAthlete?.sport = .weightTraining
            try book.confirm(edited)
            let copied = original.draftForToday(using: book.athlete)
            XCTAssertNil(copied.exercises[0].drill)
            XCTAssertEqual(copied.exercises[0].unit, index == 0 ? .meters : .reps)
            XCTAssertEqual(copied.exercises[0].sets.map(\.amount), [[3000], [20], [5]][index])
            var bad = copied
            bad.exercises = original.exercises
            XCTAssertThrowsError(try book.confirm(bad))
            try book.confirm(copied)
        }
        try book.addSkillGoal(from: XCTUnwrap(book.growthBoard.first?.current), target: 5)
        try file.save(book)
        let restored = try file.load()
        XCTAssertEqual(restored.skillGoals.count, 1)
        XCTAssertEqual(restored.entries.prefix(3).map { $0.exercises[0].drill }, originals.map { $0.exercises[0].drill })
        XCTAssertEqual(restored.entries[0].recordedAthlete?.animal, .rabbit)
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file.url)) as? [String: Any])
        let saved = try XCTUnwrap(document["notebook"] as? [String: Any])
        let goals = try XCTUnwrap(saved["savedSkillGoals"] as? [[String: Any]])
        XCTAssertEqual(goals.count, 2)
        XCTAssertEqual(goals.first?["referenceBPM"] as? Int, 150)
    }
}
