import Foundation
import XCTest
@testable import BodyNoteCore

final class RoutineTests: XCTestCase {
    func testSavingFromAnUnconfirmedDraftPersistsOnlyTheRoutine() throws {
        let file = NotebookFile(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { try? FileManager.default.removeItem(at: file.url) }
        var book = Notebook()
        var journal = book.newTrainingDraft()
        journal.kind = .rehab
        journal.exercises = [Exercise(name: "밴드 외회전", sets: [TrainingSet(amount: 8, side: .left)])]
        journal.exercises[0].note = "오늘의 동작 메모"
        journal.before = "오늘의 몸 상태"

        var template = journal.draftForToday()
        template.exercises[0].sets[0].amount = 10
        try book.saveRoutine(name: "어깨 루틴", kind: template.kind, exercises: template.exercises)
        try file.save(book)

        let reopened = try file.load()
        let routine = try XCTUnwrap(reopened.defaultRoutine)
        XCTAssertEqual(routine.name, "어깨 루틴")
        XCTAssertEqual(routine.kind, .rehab)
        XCTAssertEqual(routine.exercises[0].sets[0].amount, 10)
        XCTAssertEqual(routine.exercises[0].sets[0].side, .left)
        XCTAssertEqual(routine.exercises[0].note, "")
        XCTAssertEqual(journal.exercises[0].sets[0].amount, 8)
        XCTAssertEqual(journal.exercises[0].note, "오늘의 동작 메모")
        XCTAssertTrue(reopened.entries.isEmpty)
        XCTAssertEqual(reopened.xp, 0)
    }

    func testFirstRoutinePrefillsAnIndependentDraftUsingTodaysAthlete() throws {
        var row = Exercise(name: "  케이블 로우 ", sets: [
            TrainingSet(amount: 12, weightKg: 20, side: .left),
            TrainingSet(amount: 8, weightKg: 22.5, side: .right)
        ])
        row.equipment = "케이블"
        row.restSeconds = 60
        row.note = "그날의 운동 메모"
        var plank = Exercise(name: "플랭크", sets: [TrainingSet(amount: 30)])
        plank.unit = .seconds
        var source = JournalEntry(kind: .rehab, exercises: [row, plank])
        source.before = "시작 전"
        source.after = "끝난 후"
        source.note = "일지 메모"
        source.effort = "보통"
        var book = Notebook()
        try book.confirm(source)
        let original = book.entries[0]
        book.athlete.animal = .rabbit
        book.athlete.sport = .fieldHockey
        try book.saveRoutine(name: " 아침 재활 ", kind: original.kind, exercises: original.exercises)
        let routine = try XCTUnwrap(book.defaultRoutine)
        XCTAssertEqual(routine.name, "아침 재활")
        XCTAssertEqual(book.entries, [original])
        XCTAssertEqual(book.xp, 10)

        var draft = book.newTrainingDraft()
        XCTAssertEqual(draft.kind, .rehab)
        XCTAssertEqual(draft.recordedAthlete, book.athlete)
        XCTAssertEqual(draft.exercises.map(\.name), ["케이블 로우", "플랭크"])
        XCTAssertEqual(draft.exercises.map(\.unit), [.reps, .seconds])
        XCTAssertEqual(draft.exercises[0].sets.map(\.amount), [12, 8])
        XCTAssertEqual(draft.exercises[0].sets.map(\.weightKg), [20, 22.5])
        XCTAssertEqual(draft.exercises[0].sets.map(\.side), [.left, .right])
        XCTAssertEqual(draft.exercises[0].equipment, "케이블")
        XCTAssertEqual(draft.exercises[0].restSeconds, 60)
        XCTAssertEqual([draft.before, draft.after, draft.effort, draft.note, draft.followUp, draft.exercises[0].note],
                       Array(repeating: "", count: 6))
        XCTAssertNotEqual(draft.id, original.id)
        XCTAssertNotEqual(draft.exercises[0].id, routine.exercises[0].id)
        XCTAssertNotEqual(draft.exercises[0].sets[0].id, book.newTrainingDraft().exercises[0].sets[0].id)
        draft.exercises[0].sets[0].amount = 7
        try book.confirm(draft)
        XCTAssertEqual(book.entries.count, 2)
        XCTAssertEqual(book.entries[0], original)
        XCTAssertEqual(book.newTrainingDraft().exercises[0].sets[0].amount, 12)
    }

    func testSwitchEditClearAndDeleteDefaultsAcrossReloads() throws {
        let file = NotebookFile(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { try? FileManager.default.removeItem(at: file.url) }
        // A v1 journal written before routines existed.
        try Data(#"{"version":1,"notebook":{"entries":[],"pinnedNotes":{},"goals":[],"reflection":""}}"#.utf8)
            .write(to: file.url)
        var book = try file.load()
        XCTAssertTrue(book.routines.isEmpty)
        XCTAssertEqual(book.newTrainingDraft().exercises.first?.name, "")
        try book.saveRoutine(name: "하체", kind: .training, exercises: [Exercise(name: "스쿼트")])
        try book.saveRoutine(name: "코어", kind: .rehab, exercises: [Exercise(name: "버드독")])
        let first = book.routines[0], second = book.routines[1]
        XCTAssertEqual(book.defaultRoutineID, first.id)
        XCTAssertEqual(second.draft(using: book.athlete).exercises[0].name, "버드독")
        XCTAssertEqual(book.newTrainingDraft().exercises[0].name, "스쿼트")

        try book.setDefaultRoutine(second.id)
        try book.saveRoutine(name: "코어 B", kind: .training, exercises: [Exercise(name: "플랭크")], replacing: second.id)
        try file.save(book)
        book = try file.load()
        XCTAssertEqual(book.routines.count, 2)
        XCTAssertEqual(book.defaultRoutine?.name, "코어 B")
        XCTAssertEqual(book.defaultRoutineID, second.id)
        XCTAssertEqual(book.newTrainingDraft().exercises[0].name, "플랭크")
        try book.setDefaultRoutine(nil)
        try book.saveRoutine(name: "등", kind: .training, exercises: [Exercise(name: "로우")])
        XCTAssertEqual(book.newTrainingDraft().exercises[0].name, "")
        try book.setDefaultRoutine(first.id)
        book.deleteRoutine(second.id)
        XCTAssertEqual(book.defaultRoutineID, first.id)
        book.deleteRoutine(first.id)
        try file.save(book)
        book = try file.load()
        XCTAssertNil(book.defaultRoutineID)
        XCTAssertEqual(book.routines.map(\.name), ["등"])
        XCTAssertEqual(book.newTrainingDraft().exercises[0].name, "")
        XCTAssertTrue(book.entries.isEmpty)
        XCTAssertEqual(book.xp, 0)
    }

    func testFailedRoutineEditsLeaveTemplateAndDefaultIntact() throws {
        var book = Notebook()
        let good = Exercise(name: "로우")
        try book.saveRoutine(name: "기본", kind: .training, exercises: [good])
        let before = book
        let id = try XCTUnwrap(book.defaultRoutineID)
        XCTAssertThrowsError(try book.saveRoutine(name: " ", kind: .training, exercises: [good], replacing: id))
        XCTAssertThrowsError(try book.saveRoutine(name: "휴식", kind: .rest, exercises: [good]))
        XCTAssertThrowsError(try book.saveRoutine(name: "빈 루틴", kind: .training, exercises: []))
        let invalid = Exercise(name: "로우", sets: [TrainingSet(amount: 0)])
        XCTAssertThrowsError(try book.saveRoutine(name: "수정", kind: .rehab, exercises: [good, invalid], replacing: id))
        XCTAssertThrowsError(try book.saveRoutine(name: "수정", kind: .rehab, exercises: [good], replacing: UUID()))
        XCTAssertThrowsError(try book.setDefaultRoutine(UUID()))
        XCTAssertEqual(book, before)
    }
}
