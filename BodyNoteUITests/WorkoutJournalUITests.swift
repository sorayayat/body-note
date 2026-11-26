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
        addTeardownBlock { [self] in
            await MainActor.run {
                guard let run = self.testRun, run.failureCount > 0 || run.unexpectedExceptionCount > 0 else { return }
                let hierarchy = app.debugDescription
                print("Workout Log accessibility hierarchy at failure:\n\(hierarchy)")
                let tree = XCTAttachment(string: hierarchy)
                tree.name = "Accessibility hierarchy and frames"
                tree.lifetime = .keepAlways
                self.add(tree)
                let screen = XCTAttachment(screenshot: app.screenshot())
                screen.name = "Screen at failure"
                screen.lifetime = .keepAlways
                self.add(screen)
            }
        }
        return app
    }

    @MainActor
    func testDraftSurvivesExerciseGuideAndRelaunchBeforeCountingAsOneWorkout() {
        let app = launchSession()
        let record = app.buttons["workout.record"]
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        assertAboveTabBar(record, in: app)
        record.tap()
        let editor = app.navigationBars["오늘의 기록"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "첫 기록 버튼이 편집 화면을 열어야 합니다.")

        let name = app.textFields["exercise.name"]
        reveal(name, in: app, swipingUp: true)
        name.tap()
        name.typeText("Beta Row")
        XCTAssertEqual(name.value as? String, "Beta Row")
        let weight = app.textFields["1세트 무게 (kg)"]
        reveal(weight, in: app, swipingUp: true)
        weight.tap()
        weight.typeText("12.5")
        XCTAssertEqual(weight.value as? String, "12.5")

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
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        reveal(name, in: app, swipingUp: true)
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
        assertAboveTabBar(input, in: app)
        input.tap()
        input.typeText("Game plan")
        XCTAssertEqual(input.value as? String, "Game plan")
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
    private func assertAboveTabBar(_ control: XCUIElement, in app: XCUIApplication,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let tabs = app.buttons["코치"]
        XCTAssertTrue(tabs.exists, file: file, line: line)
        XCTAssertLessThanOrEqual(control.frame.maxY, tabs.frame.minY + 1,
            "아래쪽 컨트롤 \(control.frame)이 탭 \(tabs.frame) 위에 있어야 합니다.", file: file, line: line)
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, swipingUp: Bool,
                        file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            let list = app.collectionViews.firstMatch
            let scroller = list.exists ? list : app
            if swipingUp { scroller.swipeUp() } else { scroller.swipeDown() }
        }
        XCTAssertTrue(element.exists && element.isHittable, "입력할 컨트롤이 화면에 나타나야 합니다.", file: file, line: line)
    }
}
