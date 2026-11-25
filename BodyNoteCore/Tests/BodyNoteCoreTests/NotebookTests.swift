import Foundation
import XCTest
@testable import BodyNoteCore

final class NotebookTests: XCTestCase {
    private let utc = TimeZone(secondsFromGMT: 0)!
    private let start = Date(timeIntervalSince1970: 1_735_689_600) // 2025-01-01, 00:00 UTC

    private func day(_ index: Int) -> Date { start.addingTimeInterval(Double(index) * 86_400) }

    private func workout(_ name: String = "로우") -> JournalEntry {
        JournalEntry(exercises: [Exercise(name: name, sets: [TrainingSet(amount: 8, weightKg: 20)])])
    }

    func testDifferentRepsAndWeightsSurviveSavingAndCopyingOneExercise() throws {
        let file = NotebookFile(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { try? FileManager.default.removeItem(at: file.url) }
        let sets = [
            TrainingSet(amount: 12, weightKg: 20),
            TrainingSet(amount: 10, weightKg: 22.5),
            TrainingSet(amount: 8, weightKg: 25)
        ]
        let workout = Exercise(name: "케이블 로우", sets: sets)
        var book = Notebook()
        try book.confirm(JournalEntry(sport: .weightTraining, exercises: [workout]), at: start, timeZone: utc)
        try file.save(book)
        var reopened = try file.load()
        let original = try XCTUnwrap(reopened.entries.first)
        let recorded = try XCTUnwrap(original.exercises.first)
        XCTAssertEqual(recorded.sets, sets)

        var copy = original.draftForToday(only: recorded)
        copy.exercises[0].sets[1].weightKg = 23.75
        copy.exercises[0].sets[1].amount = 9
        try reopened.confirm(copy, at: day(1), timeZone: utc)
        try file.save(reopened)
        let history = try file.load().history(for: workout.name)
        XCTAssertEqual(history.count, 2)
        let copiedSets = try XCTUnwrap(history.first?.exercises.first?.sets)
        XCTAssertEqual(copiedSets.map(\.weightKg), [20, 23.75, 25])
        XCTAssertEqual(copiedSets.map(\.amount), [12, 9, 8])
        XCTAssertEqual(history.last, original)
    }

    func testImportCreatesAnIndependentUnconfirmedDraft() throws {
        var book = Notebook()
        var original = workout()
        original.before = "피곤함"
        original.after = "괜찮음"
        original.note = "오늘의 메모"
        original.effort = "힘듦"
        original.exercises[0].note = "마지막 세트"
        original.exercises[0].equipment = "케이블"
        try book.confirm(original, at: start, timeZone: utc)
        try book.setFollowUp("다음 날 메모", for: original.id, today: JournalDay(day(1), timeZone: utc))
        var copy = book.entries[0].draftForToday()
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertNotEqual(copy.exercises[0].id, original.exercises[0].id)
        XCTAssertNotEqual(copy.exercises[0].sets[0].id, original.exercises[0].sets[0].id)
        XCTAssertEqual(copy.exercises[0].equipment, "케이블")
        XCTAssertEqual(copy.exercises[0].sets[0].weightKg, 20)
        XCTAssertEqual([copy.before, copy.after, copy.note, copy.followUp, copy.effort, copy.exercises[0].note],
                       Array(repeating: "", count: 6))
        XCTAssertEqual(book.entries.count, 1)
        copy.exercises[0].sets[0].amount = 6
        try book.confirm(copy, at: day(1), timeZone: utc)
        XCTAssertEqual(book.entries.map { $0.exercises[0].sets[0].amount }, [8, 6])
        XCTAssertEqual(book.xp, 20)
    }

    func testRewardOncePerLocalDateIncludingMidnightAndRest() throws {
        let seoul = TimeZone(secondsFromGMT: 32_400)!
        let beforeMidnight = start.addingTimeInterval(15 * 3_600 - 1)
        var book = Notebook()
        try book.confirm(workout(), at: beforeMidnight, timeZone: seoul)
        try book.confirm(workout(), at: beforeMidnight.addingTimeInterval(1), timeZone: seoul)
        try book.confirm(workout(), at: beforeMidnight.addingTimeInterval(60), timeZone: seoul)
        try book.confirm(JournalEntry(kind: .rest), at: day(3), timeZone: seoul)
        XCTAssertEqual(book.entries.count, 4)
        XCTAssertEqual(book.activeDayCount, 2)
        XCTAssertEqual(book.xp, 20)
        XCTAssertEqual(book.level, 1)
        var rehab = workout()
        rehab.kind = .rehab
        try book.confirm(rehab, at: day(8), timeZone: seoul)
        XCTAssertEqual(book.xp, 30)
        XCTAssertEqual(book.level, 1)
    }

    func testEditingAndRepeatedConfirmationKeepDateAndRecomputeRewards() throws {
        var book = Notebook()
        var entry = workout()
        try book.confirm(entry, at: start, timeZone: utc)
        try book.confirm(entry, at: day(4), timeZone: utc)
        XCTAssertEqual(book.entries.count, 1)
        XCTAssertEqual(book.entries[0].recordedAt, start)
        XCTAssertEqual(book.xp, 10)
        entry.kind = .rest
        try book.confirm(entry, at: day(6), timeZone: utc)
        XCTAssertEqual(book.xp, 0)
        XCTAssertTrue(book.entries[0].exercises.isEmpty)
    }

    func testInvalidExerciseIsRejectedWithoutPartialChanges() throws {
        var book = Notebook()
        for bad in [JournalEntry(exercises: []), workout("  \n"),
                    JournalEntry(exercises: [Exercise(name: "로우", sets: [])])] {
            XCTAssertThrowsError(try book.confirm(bad))
        }
        var bad = workout()
        bad.exercises[0].sets[0].amount = 0
        XCTAssertThrowsError(try book.confirm(bad))
        bad.exercises[0].sets[0] = TrainingSet(amount: 1, weightKg: -0.5)
        XCTAssertThrowsError(try book.confirm(bad))
        XCTAssertTrue(book.entries.isEmpty)
    }

    func testHistoryPinAndNextDayNoteAreIndependentOfDailyObservations() throws {
        var book = Notebook()
        var first = workout(" Band   Row ")
        first.exercises.append(Exercise(name: "밴드 외회전"))
        try book.confirm(first, at: start, timeZone: utc)
        try book.confirm(workout("band row"), at: day(1), timeZone: utc)
        XCTAssertEqual(book.history(for: "BAND ROW").count, 2)
        XCTAssertEqual(Set(book.exerciseNames), Set(["band row", "밴드 외회전"]))
        let single = first.draftForToday(only: first.exercises[1])
        XCTAssertEqual(single.exercises.map(\.name), ["밴드 외회전"])
        book.pin(" 좌석 4칸 ", for: "Band Row")
        XCTAssertEqual(book.pinnedNotes["band row"], "좌석 4칸")
        XCTAssertThrowsError(try book.setFollowUp("메모", for: first.id, today: JournalDay(start, timeZone: utc)))
        try book.setFollowUp("메모", for: first.id, today: JournalDay(day(1), timeZone: utc))
        try book.confirm(first, at: day(3), timeZone: utc)
        XCTAssertEqual(book.entries.first?.followUp, "메모")
        XCTAssertEqual(book.xp, 20)
        book.pin("", for: "BAND ROW")
        XCTAssertNil(book.pinnedNotes["band row"])
    }

    func testChapterAndCustomGoalUseQualifyingJournalEntries() throws {
        var book = Notebook()
        try book.confirm(workout(), at: start, timeZone: utc)
        try book.addGoal(exerciseName: "로우", targetDays: 2, start: JournalDay(day(1), timeZone: utc))
        let goal = try XCTUnwrap(book.goals.first)
        XCTAssertThrowsError(try book.saveReflection("한 줄"))
        let first = workout()
        try book.confirm(first, at: day(1), timeZone: utc)
        try book.confirm(workout(), at: day(1).addingTimeInterval(100), timeZone: utc)
        try book.confirm(workout("러닝"), at: day(2), timeZone: utc)
        let second = workout()
        try book.confirm(second, at: day(3), timeZone: utc)
        for index in 4...5 { try book.confirm(workout(), at: day(index), timeZone: utc) }
        XCTAssertEqual(book.entriesContributing(to: goal).map(\.id), [first.id, second.id])
        XCTAssertEqual(book.activeDayCount, 6)
        XCTAssertFalse(book.hasMatArea)
        XCTAssertThrowsError(try book.saveReflection("   "))
        try book.saveReflection("이번 주에는 자세를 기억했다.")
        XCTAssertTrue(book.hasMatArea)
    }

    func testEverySkinUsesTheSameTrainingDraftAndCopiesItsAppearance() throws {
        var book = Notebook()
        XCTAssertEqual(TrainingSport.available, [.running, .fieldHockey, .weightTraining, .basic])
        for animal in Animal.allCases {
            book.athlete.animal = animal
            for sport in TrainingSport.available {
                book.athlete.sport = sport
                let entry = book.athlete.newEntry()
                XCTAssertNil(entry.sport)
                XCTAssertEqual(entry.kind, .training)
                XCTAssertEqual(entry.recordedAthlete, book.athlete)
                XCTAssertEqual(entry.draftForToday().recordedAthlete?.sport, sport)
                XCTAssertEqual(book.xp, 0)
            }
        }
        var entry = book.athlete.newEntry()
        entry.exercises = [Exercise(name: "밴드")]
        try book.confirm(entry, at: start, timeZone: utc)
        book.athlete.sport = .weightTraining
        XCTAssertEqual(book.entries[0].draftForToday().recordedAthlete?.sport, .basic)
        XCTAssertEqual(book.xp, 10)
        let restored = try JSONDecoder().decode(Notebook.self, from: JSONEncoder().encode(book))
        XCTAssertEqual(restored.athlete, book.athlete)
        entry.kind = .rest
        try book.confirm(entry)
        XCTAssertNil(book.entries[0].sport)
        XCTAssertNil(book.entries[0].recordedAthlete)
        XCTAssertEqual(book.xp, 0)
    }

    func testRetiredSportsKeepTheirHistoryAndOpenWithAnAvailableKit() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let file = NotebookFile(url: url)
        var template = Notebook()
        try template.confirm(workout(), at: start, timeZone: utc)
        let encoded = try JSONEncoder().encode(template)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        for retired in [TrainingSport.soccer, .basketball] {
            var athlete = Athlete()
            athlete.sport = retired
            XCTAssertEqual(athlete.newEntry().recordedAthlete?.sport, .running)
            var legacy = object
            var entries = try XCTUnwrap(object["entries"] as? [[String: Any]])
            entries[0]["sport"] = retired.rawValue
            entries[0].removeValue(forKey: "recordedAthlete")
            legacy["entries"] = entries
            legacy["savedAthlete"] = ["animal": "rabbit", "sport": retired.rawValue]
            let bytes = try JSONSerialization.data(withJSONObject: ["version": 1, "notebook": legacy])
            try bytes.write(to: url)

            var book = try file.load()
            XCTAssertEqual(book.athlete.animal, .rabbit)
            XCTAssertEqual(book.athlete.sport, .running)
            XCTAssertEqual(book.xp, 10)
            var original = try XCTUnwrap(book.entries.first)
            XCTAssertEqual(original.sport, retired)
            XCTAssertEqual(original.recordedAthlete, book.athlete)
            original.note = "이전 기록에 메모 추가"
            try book.confirm(original)
            var copy = original.draftForToday()
            XCTAssertNil(copy.sport)
            XCTAssertNil(original.draftForToday(only: original.exercises[0]).sport)
            XCTAssertEqual(copy.exercises[0].sets.map(\.amount), original.exercises[0].sets.map(\.amount))
            copy.recordedAthlete?.sport = .fieldHockey
            try book.confirm(copy, at: day(2), timeZone: utc)
            try file.save(book)
            let restored = try file.load()
            XCTAssertEqual(restored.entries.map(\.sport), [retired, nil])
            XCTAssertEqual(restored.entries.map(\.recordedAthlete?.sport), [.running, .fieldHockey])
            XCTAssertEqual(restored.entries[0], original)
            XCTAssertEqual(restored.xp, 20)
        }
    }

    func testLegacyJournalWithoutAthleteOrSportKeepsExistingRecords() throws {
        var book = Notebook()
        try book.confirm(workout(), at: start, timeZone: utc)
        let data = try JSONEncoder().encode(book)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(json["savedAthlete"])
        let restored = try JSONDecoder().decode(Notebook.self, from: data)
        XCTAssertEqual(restored.athlete.animal, .cat)
        XCTAssertEqual(restored.athlete.sport, .running)
        XCTAssertNil(restored.entries[0].sport)
        XCTAssertEqual(restored.entries, book.entries)
        XCTAssertEqual(restored.xp, 10)
    }

    func testLevelUsesHundredXPAndReadsOnlyConfirmedDays() throws {
        var book = Notebook()
        XCTAssertEqual(book.remainingXP, 100)
        for n in 0..<9 { try book.confirm(workout(), at: day(n), timeZone: utc) }
        XCTAssertEqual(book.remainingXP, 10)
        XCTAssertEqual(book.level, 1)
        book.lastReadTrainingDays = book.activeDayCount
        XCTAssertFalse(book.hasTrainingNews)
        try book.confirm(workout(), at: day(9), timeZone: utc)
        XCTAssertTrue(book.hasTrainingNews)
        XCTAssertEqual(book.level, 2)
        XCTAssertEqual(book.levelXP, 0)
        XCTAssertEqual(book.remainingXP, 100)
        try book.confirm(workout(), at: day(9), timeZone: utc)
        XCTAssertEqual(book.xp, 100)
    }

    func testAtomicFileRoundTripAndCorruptFileFailure() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = NotebookFile(url: dir.appendingPathComponent("journal.json"))
        XCTAssertEqual(try file.load(), Notebook())
        var book = Notebook()
        try book.confirm(workout(), at: start, timeZone: utc)
        book.pin("4칸", for: "로우")
        try file.save(book)
        XCTAssertEqual(try file.load(), book)
        let broken = Data("broken".utf8)
        try broken.write(to: file.url)
        XCTAssertThrowsError(try file.load())
        XCTAssertEqual(try Data(contentsOf: file.url), broken)
    }
}
