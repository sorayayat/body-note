import XCTest
@testable import BodyNoteCore

final class ExerciseCatalogTests: XCTestCase {
    let catalog = ExerciseCatalog.bundled

    func testBundledEntriesHaveUniqueIDsRegionsAndLocalIllustrations() throws {
        XCTAssertFalse(catalog.items.isEmpty)
        XCTAssertEqual(Set(catalog.items.map(\.id)).count, catalog.items.count)
        XCTAssertEqual(Set(catalog.regions), Set(catalog.items.flatMap(\.regions)))
        for item in catalog.items {
            XCTAssertFalse(item.description.isEmpty)
            XCTAssertFalse(item.regions.isEmpty)
            let url = try XCTUnwrap(ExerciseCatalog.resources.url(forResource: item.id, withExtension: "png",
                                                                   subdirectory: "ExerciseArt"), item.id)
            XCTAssertEqual(try Data(contentsOf: url).prefix(8), Data([137, 80, 78, 71, 13, 10, 26, 10]))
        }
    }

    func testSearchRanksAliasesAndCombinesBodyPartsWithOtherTerms() {
        XCTAssertEqual(catalog.search("  스퀏 ").first?.id, "bodyweight-squat")
        XCTAssertEqual(catalog.search("ＳＱＵＡＴ").first?.id, "bodyweight-squat")
        XCTAssertEqual(catalog.search("  SIDE-plank").first?.id, "side-plank")
        XCTAssertEqual(catalog.search("플랭").map(\.id), ["plank", "side-plank"])
        XCTAssertEqual(catalog.search("등 밴드", region: "어깨").map(\.id), ["band-pull-apart"])
        XCTAssertEqual(catalog.search("무릎 펴기", region: "하체").first?.id, "leg-extension")
        XCTAssertTrue(catalog.search("팔굽혀", region: "코어").isEmpty)
        XCTAssertTrue(catalog.search("???").isEmpty)
        XCTAssertEqual(catalog.entry(named: "  케이블   로우 ")?.id, "seated-cable-row")
        XCTAssertNil(catalog.entry(named: "무릎"))
        XCTAssertEqual(catalog.search("  ", region: "무릎"), catalog.items.filter { $0.regions.contains("무릎") })
    }

    func testSelectionOnlySetsUnitOnFreshRowAndKeepsCopiedSetsIndependent() throws {
        let plank = try XCTUnwrap(catalog.search("플랭크").first)
        var fresh = Exercise()
        XCTAssertTrue(fresh.isBlankCatalogRow)
        fresh.selectFromCatalog(plank, useDefaultUnit: fresh.isBlankCatalogRow)
        XCTAssertEqual(fresh.name, "플랭크")
        XCTAssertEqual(fresh.unit, .seconds)

        var custom = Exercise(name: "나만의 동작", sets: [
            TrainingSet(amount: 6, weightKg: 12.5, side: .left), TrainingSet(amount: 8, weightKg: 10, side: .right)
        ])
        custom.equipment = "노란 밴드"
        custom.note = "마지막 세트 기록"
        custom.restSeconds = 60
        let original = JournalEntry(kind: .rehab, exercises: [custom])
        var copy = try XCTUnwrap(original.draftForToday().exercises.first)
        let sets = copy.sets
        XCTAssertFalse(copy.isBlankCatalogRow)
        copy.selectFromCatalog(plank, useDefaultUnit: false)
        XCTAssertEqual(copy.name, "플랭크")
        XCTAssertEqual(copy.unit, .reps)
        XCTAssertEqual(copy.sets, sets)
        XCTAssertEqual(copy.equipment, custom.equipment)
        XCTAssertEqual(copy.restSeconds, 60)
        XCTAssertEqual(original.exercises, [custom])
    }

    func testPartlyTypedFreshNameStillAdoptsCatalogUnitAfterDiskReload() throws {
        let plank = try XCTUnwrap(catalog.search("forearm plank").first)
        let file = NotebookFile(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        defer { try? FileManager.default.removeItem(at: file.url) }
        var draft = WorkoutDraft(JournalEntry())
        draft.entry.exercises[0].beginCatalogNameEdit(in: &draft.numbers)
        draft.entry.exercises[0].name = "fore"
        var book = Notebook()
        book.keepDraft(draft)
        try file.save(book)
        var reopened = try XCTUnwrap(file.load().drafts.first)
        XCTAssertEqual(reopened.entry.exercises[0].name, "fore")
        XCTAssertFalse(reopened.entry.exercises[0].isBlankCatalogRow)
        reopened.entry.exercises[0].selectFromCatalog(plank, inputs: &reopened.numbers)
        XCTAssertEqual(reopened.entry.exercises[0].name, plank.name)
        XCTAssertEqual(reopened.entry.exercises[0].unit, .seconds)
        XCTAssertEqual(reopened.entry.exercises[0].sets, draft.entry.exercises[0].sets)
    }

    func testCopiedOrExplicitlyConfiguredUnitsSurviveCatalogRename() throws {
        let plank = try XCTUnwrap(catalog.search("plank").first)
        let original = JournalEntry(exercises: [Exercise(name: "Row")])
        var book = Notebook()
        try book.saveRoutine(name: "Morning", kind: .training, exercises: original.exercises)
        for entry in [original, original.draftForToday(), book.newTrainingDraft()] {
            var row = entry.exercises[0]
            var inputs: [String: String] = [:]
            row.beginCatalogNameEdit(in: &inputs)
            row.name = ""
            row.beginCatalogNameEdit(in: &inputs)
            row.name = "pla"
            row.selectFromCatalog(plank, inputs: &inputs)
            XCTAssertEqual(row.unit, .reps)
        }
        for field in ["amount", "weight", "unit"] {
            var row = Exercise()
            var inputs: [String: String] = [:]
            row.beginCatalogNameEdit(in: &inputs)
            row.name = "pla"
            if field == "unit" {
                row.keepCatalogUnit(in: &inputs)
                row.unit = .seconds
                row.unit = .reps
            } else {
                inputs["\(field)-\(row.sets[0].id)"] = field == "amount" ? "10" : ""
            }
            row.selectFromCatalog(plank, inputs: &inputs)
            XCTAssertEqual(row.unit, .reps, field)
        }
    }
}
