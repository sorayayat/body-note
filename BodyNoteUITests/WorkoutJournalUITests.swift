import XCTest

final class WorkoutJournalUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchSession() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["WORKOUT_LOG_UI_TEST_SESSION"] = UUID().uuidString
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        return app
    }

    @MainActor
    func testDraftSurvivesExerciseGuideAndRelaunchBeforeCountingAsOneWorkout() {
        let app = launchSession()
        let record = app.buttons["workout.record"]
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        record.tap()

        let name = app.textFields["exercise.name"]
        reveal(name, in: app, swipingUp: true)
        name.tap()
        name.typeText("Beta Row")
        let weight = app.textFields["1세트 무게 (kg)"]
        reveal(weight, in: app, swipingUp: true)
        weight.tap()
        weight.typeText("12.5")

        let library = app.buttons["exercise.library"]
        reveal(library, in: app, swipingUp: false)
        library.tap()
        let squat = app.buttons["exercise.item.bodyweight-squat"]
        reveal(squat, in: app, swipingUp: true)
        squat.tap()
        let detailBar = app.navigationBars["스쿼트"]
        XCTAssertTrue(detailBar.waitForExistence(timeout: 5))
        detailBar.buttons.element(boundBy: 0).tap()
        let closeLibrary = app.buttons["exercise.library.close"]
        XCTAssertTrue(closeLibrary.waitForExistence(timeout: 5))
        closeLibrary.tap()
        reveal(name, in: app, swipingUp: false)
        XCTAssertEqual(name.value as? String, "Beta Row")
        reveal(weight, in: app, swipingUp: true)
        XCTAssertEqual(weight.value as? String, "12.5")

        app.terminate()
        app.launch()
        XCTAssertTrue(weekSummary(days: 0, sets: 0, in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Beta Row")
        reveal(weight, in: app, swipingUp: true)
        XCTAssertEqual(weight.value as? String, "12.5")
        let confirm = app.buttons["workout.confirm"]
        reveal(confirm, in: app, swipingUp: true)
        confirm.tap()
        XCTAssertTrue(weekSummary(days: 1, sets: 1, in: app).waitForExistence(timeout: 10))

        app.buttons["일지"].tap()
        let entry = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Beta Row")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        XCTAssertTrue(app.navigationBars["Beta Row"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testUnsentCoachMessageSurvivesRelaunchAndEmptyHistoryHasNoInventedActivity() {
        let app = launchSession()
        let coach = app.buttons["코치"]
        XCTAssertTrue(coach.waitForExistence(timeout: 10))
        coach.tap()
        let input = app.descendants(matching: .any)["coach.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("Game plan")
        app.terminate()
        app.launch()
        XCTAssertTrue(coach.waitForExistence(timeout: 10))
        coach.tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, "Game plan")
        app.buttons["최근 운동을 돌아볼래"].tap()
        app.buttons["coach.send"].tap()
        let reply = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "확정한 운동이 아직 없어")).firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 10))
    }

    @MainActor
    private func weekSummary(days: Int, sets: Int, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
            "운동 \(days)일", "\(sets)세트")).firstMatch
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, swipingUp: Bool,
                        file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            if swipingUp { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(element.exists && element.isHittable, "입력할 컨트롤이 화면에 나타나야 합니다.", file: file, line: line)
    }
}
