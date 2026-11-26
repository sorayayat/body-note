import XCTest
@testable import BodyNoteCore

final class SideProgressTests: XCTestCase {
    private let zone = TimeZone(secondsFromGMT: 0)!
    private let start = Date(timeIntervalSince1970: 1_735_689_600)

    private func exercise(_ sets: [TrainingSet], name: String = "밴드 외회전",
                          equipment: String = "노란 밴드", unit: ExerciseUnit = .reps) -> Exercise {
        var value = Exercise(name: name, sets: sets)
        value.equipment = equipment
        value.unit = unit
        return value
    }

    private func confirm(_ entry: JournalEntry, in book: inout Notebook, day: Int) throws {
        try book.confirm(entry, at: start.addingTimeInterval(Double(day * 86_400)), timeZone: zone)
    }

    func testEachSideUsesItsOwnLatestTwoSessionsAndLastMatchingSet() throws {
        let baseline = JournalEntry(kind: .rehab, exercises: [exercise([
            TrainingSet(amount: 6, side: .left), TrainingSet(amount: 8, side: .left),
            TrainingSet(amount: 10, side: .right), TrainingSet(amount: 30, side: .both)
        ])])
        let rightDay = JournalEntry(exercises: [exercise([TrainingSet(amount: 10, side: .right)])])
        let leftDay = JournalEntry(exercises: [
            exercise([TrainingSet(amount: 11, side: .left)]),
            exercise([TrainingSet(amount: 10, side: .left)], name: "밴드   외회전", equipment: " 노란  밴드 ")
        ])
        var book = Notebook()
        try confirm(baseline, in: &book, day: 0)
        try confirm(rightDay, in: &book, day: 1)
        try confirm(leftDay, in: &book, day: 2)
        try confirm(JournalEntry(kind: .rest), in: &book, day: 3)
        let cards = book.sideProgress(for: " 밴드 외회전 ")
        XCTAssertEqual(cards.count, 1)
        let card = try XCTUnwrap(cards.first)
        XCTAssertEqual(card.left.previous?.amount, 8)
        XCTAssertEqual(card.left.previous?.entryID, baseline.id)
        XCTAssertEqual(card.left.latest?.entryID, leftDay.id)
        XCTAssertEqual(card.left.change, 2)
        XCTAssertEqual(card.right.previous?.entryID, baseline.id)
        XCTAssertEqual(card.right.latest?.entryID, rightDay.id)
        XCTAssertEqual(card.right.change, 0)
        XCTAssertNotEqual(card.left.latest?.day, card.right.latest?.day)

        var edited = baseline
        edited.exercises[0].sets[1].amount = 12
        try confirm(edited, in: &book, day: 7)
        XCTAssertEqual(book.sideProgress()[0].left.change, -2)
        XCTAssertEqual(book.sideProgress()[0].left.latest?.entryID, leftDay.id)
        edited.kind = .rest
        try confirm(edited, in: &book, day: 7)
        XCTAssertNil(book.sideProgress()[0].left.previous)
        XCTAssertNil(book.sideProgress()[0].right.previous)
        XCTAssertEqual(book.xp, 20)
    }

    func testWeightEquipmentUnitsAndCustomNamesKeepIndependentBaselines() throws {
        let first = JournalEntry(exercises: [exercise([TrainingSet(amount: 12, weightKg: 2.5, side: .left)])])
        let next = JournalEntry(kind: .rehab, exercises: [
            exercise([TrainingSet(amount: 8, side: .left), TrainingSet(amount: 9, weightKg: 0, side: .left),
                      TrainingSet(amount: 10, weightKg: 2.5, side: .left)]),
            exercise([TrainingSet(amount: 30, weightKg: 2.5, side: .left)], unit: .seconds),
            exercise([TrainingSet(amount: 1, weightKg: 2.5, side: .left)], unit: .minutes),
            exercise([TrainingSet(amount: 42, weightKg: 2.5, side: .right)], equipment: "파란 밴드"),
            exercise([TrainingSet(amount: 4, side: .left)], name: "내 동작", unit: .meters)
        ])
        var book = Notebook()
        try confirm(first, in: &book, day: 0)
        try confirm(next, in: &book, day: 0)
        let cards = book.sideProgress()
        XCTAssertEqual(cards.count, 7)
        let paired = try XCTUnwrap(cards.first { $0.left.previous != nil })
        XCTAssertEqual(paired.left.change, -2)
        XCTAssertEqual(paired.left.previous?.entryID, first.id)
        XCTAssertEqual(paired.left.latest?.entryID, next.id)
        XCTAssertNil(paired.right.latest)
        XCTAssertTrue(cards.filter { $0.id != paired.id }.allSatisfy { $0.left.change == nil && $0.right.change == nil })
        XCTAssertEqual(book.sideProgress(for: "내 동작").first?.id.unit, .meters)
        XCTAssertTrue(book.sideProgress(for: "다른 운동").isEmpty)
        XCTAssertEqual(book.xp, 10)
    }

    func testOnlyExplicitUnilateralSetsEnterTheCardIncludingAfterReload() throws {
        var book = Notebook()
        let value = exercise([TrainingSet(amount: 12), TrainingSet(amount: 12, side: .both)])
        try confirm(JournalEntry(exercises: [value]), in: &book, day: 0)
        XCTAssertTrue(book.sideProgress().isEmpty)
        let first = JournalEntry(exercises: [exercise([TrainingSet(amount: 11, side: .right)])])
        try confirm(first, in: &book, day: 2)
        let restored = try JSONDecoder().decode(Notebook.self, from: JSONEncoder().encode(book))
        let card = try XCTUnwrap(restored.sideProgress().first)
        XCTAssertNil(card.left.latest)
        XCTAssertNil(card.right.change)
        XCTAssertEqual(card.right.latest?.entryID, first.id)
        XCTAssertEqual(card.right.latest?.amount, 11)
    }
}
