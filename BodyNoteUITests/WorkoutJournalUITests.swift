import XCTest
import UIKit

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
        assertValue("Beta Row", in: name)
        let weight = app.textFields["1세트 무게 (kg)"]
        reveal(weight, in: app, swipingUp: true)
        weight.tap()
        weight.typeText("12.5")
        assertValue("12.5", in: weight)

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
        assertValue("Beta Row", in: name)
        reveal(weight, in: app, swipingUp: true)
        assertValue("12.5", in: weight)

        app.terminate()
        app.launch()
        XCTAssertTrue(weekSummary(days: 0, sets: 0, in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        reveal(name, in: app, swipingUp: true)
        assertValue("Beta Row", in: name)
        reveal(weight, in: app, swipingUp: true)
        assertValue("12.5", in: weight)
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
    func testFirstRoutinePrefillsTodayWithoutChangingTheTemplateOrCountingADraft() {
        let app = launchSession()
        let summary = weekSummary(days: 0, sets: 0, in: app)
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        let routines = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "내 루틴")).firstMatch
        reveal(routines, in: app, swipingUp: true)
        routines.tap()
        let create = app.buttons["루틴 만들기"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        create.tap()

        let title = app.textFields["루틴 이름"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Morning Set")
        let name = app.textFields["exercise.name"]
        reveal(name, in: app, swipingUp: true)
        name.tap()
        name.typeText("Beta Row")
        assertValue("Beta Row", in: name)
        app.navigationBars["루틴 만들기"].buttons["저장"].tap()
        let list = app.navigationBars["내 루틴"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["기본 루틴 해제"].exists)
        list.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 5))

        let record = app.buttons["workout.record"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        let editor = app.navigationBars["오늘의 기록"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        reveal(name, in: app, swipingUp: true)
        assertValue("Beta Row", in: name)
        let addSet = app.buttons["세트 추가"]
        reveal(addSet, in: app, swipingUp: true)
        addSet.tap()
        let secondSet = app.textFields["2세트 횟수 (회)"]
        reveal(secondSet, in: app, swipingUp: true)
        assertValue("10", in: secondSet)
        editor.buttons["닫기"].tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 5))

        reveal(routines, in: app, swipingUp: true)
        routines.tap()
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Morning Set"].exists)
        XCTAssertTrue(app.staticTexts["Beta Row 1세트"].exists)
    }

    @MainActor
    func testCatalogFiltersBySelectedBodyAreaAndAliasAndAppliesTheExerciseUnit() {
        let app = launchSession()
        let record = app.buttons["workout.record"]
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        record.tap()
        XCTAssertTrue(app.navigationBars["오늘의 기록"].waitForExistence(timeout: 5))
        let name = app.textFields["exercise.name"]
        reveal(name, in: app, swipingUp: true)
        name.tap()
        name.typeText("fore")
        assertValue("fore", in: name)
        app.terminate()
        app.launch()
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        record.tap()
        XCTAssertTrue(app.navigationBars["오늘의 기록"].waitForExistence(timeout: 5))
        reveal(name, in: app, swipingUp: true)
        assertValue("fore", in: name)
        let library = app.buttons["exercise.library"]
        reveal(library, in: app, swipingUp: true)
        library.tap()
        let knee = app.buttons["무릎"]
        XCTAssertTrue(knee.waitForExistence(timeout: 5))
        knee.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("forearm plank\n")
        XCTAssertTrue(app.staticTexts["찾은 동작이 없어요"].waitForExistence(timeout: 5))

        let core = app.buttons["코어"]
        reveal(core, in: app, swipingUp: false)
        core.tap()
        let plank = app.buttons["exercise.item.plank"]
        reveal(plank, in: app, swipingUp: true)
        plank.tap()
        XCTAssertTrue(app.navigationBars["플랭크"].waitForExistence(timeout: 5))
        let select = app.buttons["이 동작 선택"]
        reveal(select, in: app, swipingUp: true)
        select.tap()
        XCTAssertTrue(app.navigationBars["오늘의 기록"].waitForExistence(timeout: 5))
        reveal(name, in: app, swipingUp: false)
        assertValue("플랭크", in: name)
        let seconds = app.textFields["1세트 시간 (초)"]
        reveal(seconds, in: app, swipingUp: true)
        assertValue("10", in: seconds)
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
        assertValue("Game plan", in: input)
        app.terminate()
        app.launch()
        XCTAssertTrue(coach.waitForExistence(timeout: 10))
        coach.tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        assertValue("Game plan", in: input)
        app.buttons["최근 운동을 돌아볼래"].tap()
        app.buttons["coach.send"].tap()
        let reply = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "확정한 운동이 아직 없어")).firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 10))
    }

    @MainActor
    func testGroundAndLockerReturnToAnUnconfirmedWorkoutDraft() {
        let app = launchSession()
        let record = app.buttons["workout.record"]
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        record.tap()
        let editor = app.navigationBars["오늘의 기록"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        let name = app.textFields["exercise.name"]
        reveal(name, in: app, swipingUp: true)
        name.tap()
        name.typeText("Locker Row")
        assertValue("Locker Row", in: name)
        let weight = app.textFields["1세트 무게 (kg)"]
        reveal(weight, in: app, swipingUp: true)
        weight.tap()
        weight.typeText("18.")
        assertValue("18.", in: weight)
        editor.buttons["닫기"].tap()

        let summary = weekSummary(days: 0, sets: 0, in: app)
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        let ground = app.buttons["training.ground"]
        reveal(ground, in: app, swipingUp: true)
        XCTAssertEqual(ground.label, "훈련장 보기")
        ground.tap()
        let groundBar = app.navigationBars["기초 훈련장"]
        XCTAssertTrue(groundBar.waitForExistence(timeout: 5))
        let locker = app.buttons["athlete.locker"]
        reveal(locker, in: app, swipingUp: true)
        XCTAssertEqual(locker.label, "선수·스킨 변경")
        locker.tap()
        let lockerBar = app.navigationBars["선수 라커룸"]
        XCTAssertTrue(lockerBar.waitForExistence(timeout: 5))
        let rabbit = app.buttons["토끼"]
        reveal(rabbit, in: app, swipingUp: true)
        rabbit.tap()
        XCTAssertTrue(rabbit.isSelected)
        let hockey = app.buttons["필드하키"]
        reveal(hockey, in: app, swipingUp: true)
        hockey.tap()
        XCTAssertTrue(hockey.isSelected)
        XCTAssertTrue(lockerBar.exists)
        lockerBar.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(groundBar.waitForExistence(timeout: 5))
        groundBar.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        reveal(name, in: app, swipingUp: true)
        assertValue("Locker Row", in: name)
        reveal(weight, in: app, swipingUp: true)
        assertValue("18.", in: weight)
    }

    @MainActor
    func testIPadDrawingSurvivesRelaunchAndAttachesToJournal() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "그림 작성은 iPad에서 확인합니다.")
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }

        let app = launchSession()
        let record = app.buttons["workout.record"]
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        record.tap()
        let rest = app.segmentedControls.buttons["휴식"]
        XCTAssertTrue(rest.waitForExistence(timeout: 8))
        rest.tap()
        let draw = app.buttons["journal.attachment.draw"]
        reveal(draw, in: app, swipingUp: true)
        draw.tap()
        let paper = app.descendants(matching: .any)["journal.drawing.canvas"].firstMatch
        let attach = app.buttons["journal.drawing.attach"]
        XCTAssertTrue(paper.waitForExistence(timeout: 8))
        XCTAssertFalse(attach.isEnabled)
        let start = paper.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.35))
        let end = paper.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.60))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        let ink = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: attach)
        XCTAssertEqual(XCTWaiter.wait(for: [ink], timeout: 8), .completed)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(paper.isHittable)
        XCTAssertTrue(attach.isEnabled)
        app.terminate()
        app.launch()

        XCTAssertTrue(record.waitForExistence(timeout: 10))
        record.tap()
        reveal(draw, in: app, swipingUp: true)
        draw.tap()
        XCTAssertTrue(paper.waitForExistence(timeout: 8))
        XCTAssertTrue(attach.isEnabled, "재실행 후 새 획을 그리지 않아도 이전 그림을 첨부할 수 있어야 합니다.")
        attach.tap()
        let thumbnail = app.buttons["journal.attachment.thumbnail.drawing"].firstMatch
        XCTAssertTrue(thumbnail.waitForExistence(timeout: 8))
        let confirm = app.buttons["workout.confirm"]
        reveal(confirm, in: app, swipingUp: true)
        confirm.tap()
        openJournalEntry("휴식 기록", in: app)
        reveal(thumbnail, in: app, swipingUp: true)
        thumbnail.tap()
        XCTAssertTrue(app.navigationBars["그림 보기"].waitForExistence(timeout: 8))
        let image = app.images["journal.attachment.image"].firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 8))
        XCTAssertTrue(hasCentralInk(image.screenshot()), "저장한 이미지 중앙에 그린 펜 자국이 보여야 합니다.")
    }

    @MainActor
    func testPhotoPickerAttachesAnImageToJournal() {
        let app = launchSession()
        let record = app.buttons["workout.record"]
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        record.tap()
        let name = app.textFields["exercise.name"]
        reveal(name, in: app, swipingUp: true)
        name.tap()
        name.typeText("Photo Row")
        assertValue("Photo Row", in: name)
        let choose = app.buttons["journal.attachment.photo"]
        reveal(choose, in: app, swipingUp: true)
        choose.tap()

        // The picker repeats the thumbnails' labels on their non-interactive group.
        // The seeded image is the most recent asset, in either system language.
        let assetLabel = NSPredicate(format:
            "label CONTAINS[c] %@ OR label BEGINSWITH[c] %@ OR label BEGINSWITH %@",
            "WorkoutLogAttachmentFixture", "Photo,", "사진,")
        let asset = app.images.matching(assetLabel).firstMatch
        if asset.waitForExistence(timeout: 8) {
            asset.tap()
        } else {
            let gridAsset = app.collectionViews["PhotosGridView"].cells.firstMatch
            XCTAssertTrue(gridAsset.waitForExistence(timeout: 5), "시스템 사진 선택기에 테스트 사진이 있어야 합니다.")
            gridAsset.tap()
        }
        let add = app.buttons.matching(NSPredicate(format:
            "label BEGINSWITH[c] %@ OR label BEGINSWITH %@ OR label IN %@",
            "Add", "추가", ["Done", "완료"])).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 8))
        let selectionReady = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: add)
        XCTAssertEqual(XCTWaiter.wait(for: [selectionReady], timeout: 8), .completed)
        add.tap()
        let thumbnail = app.buttons["journal.attachment.thumbnail.photo"].firstMatch
        XCTAssertTrue(thumbnail.waitForExistence(timeout: 15))
        app.terminate()
        app.launch()
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        record.tap()
        reveal(thumbnail, in: app, swipingUp: true)
        let confirm = app.buttons["workout.confirm"]
        reveal(confirm, in: app, swipingUp: true)
        confirm.tap()
        openJournalEntry("Photo Row", in: app)
        reveal(thumbnail, in: app, swipingUp: true)
        thumbnail.tap()
        XCTAssertTrue(app.navigationBars["사진 보기"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.images["journal.attachment.image"].firstMatch.waitForExistence(timeout: 8))
    }

    /// The black test stroke crosses the center of an otherwise white page.
    @MainActor
    private func hasCentralInk(_ screenshot: XCUIScreenshot) -> Bool {
        guard let image = screenshot.image.cgImage else { return false }
        let size = 384
        var pixels = [UInt8](repeating: 255, count: size * size)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: size, height: size,
                bitsPerComponent: 8, bytesPerRow: size, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size)))
            return true
        }
        guard rendered else { return false }
        let center = (size / 4)..<(3 * size / 4)
        return center.contains { y in center.contains { x in pixels[y * size + x] < 180 } }
    }

    @MainActor
    private func openJournalEntry(_ title: String, in app: XCUIApplication,
                                  file: StaticString = #filePath, line: UInt = #line) {
        let journal = app.buttons["일지"]
        let canOpen = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: journal)
        XCTAssertEqual(XCTWaiter.wait(for: [canOpen], timeout: 10), .completed, file: file, line: line)
        journal.tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), file: file, line: line)
        row.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8), file: file, line: line)
    }

    @MainActor
    private func assertValue(_ expected: String, in field: XCUIElement,
                             file: StaticString = #filePath, line: UInt = #line) {
        let completeValue = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected),
                                                      object: field)
        XCTAssertEqual(XCTWaiter.wait(for: [completeValue], timeout: 10), .completed,
            "입력란에 전체 값 '\(expected)'이 표시되어야 합니다. 현재 값: \(String(describing: field.value))",
            file: file, line: line)
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
        let screen = app.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let keyboard = app.keyboards.firstMatch
        for _ in 0..<14 {
            let bars = app.navigationBars.allElementsBoundByIndex
            let navBottom = bars.map { $0.frame.maxY }.max() ?? screen.minY
            let top = max(screen.minY + 48, navBottom) + 10
            let keyboardFrame = keyboard.exists ? keyboard.frame : .zero
            let keyboardTop = keyboardFrame.isEmpty ? screen.maxY : keyboardFrame.minY
            let bottom = min(screen.maxY - 42, keyboardTop) - 10
            guard bottom - top > 60 else {
                XCTFail("스크롤할 화면이 가려져 있어요.", file: file, line: line)
                return
            }
            let center = (top + bottom) / 2
            let maximumDrag = min((bottom - top) * 0.45, 230)
            var distance = swipingUp ? maximumDrag : -maximumDrag
            if element.exists, !element.frame.isEmpty {
                let target = element.frame.midY
                if (top...bottom).contains(target) && element.isHittable { return }
                let displacement = target - center
                distance = (displacement >= 0 ? 1 : -1) * min(max(abs(displacement), 75), maximumDrag)
            }
            let x: CGFloat
            if UIDevice.current.userInterfaceIdiom == .pad {
                // A centered iPad sheet can leave the left side of the window outside the form.
                let bar = bars.last { !$0.frame.isEmpty && $0.isHittable }
                x = bar.map { $0.frame.minX - screen.minX + $0.frame.width * 0.14 } ?? screen.width * 0.55
            } else {
                x = screen.width * 0.14
            }
            let start = origin.withOffset(CGVector(dx: x, dy: center + distance / 2 - screen.minY))
            let end = origin.withOffset(CGVector(dx: x, dy: center - distance / 2 - screen.minY))
            start.press(forDuration: 0.04, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTFail("스크롤한 뒤에도 \(element) 컨트롤을 누를 수 없어요.", file: file, line: line)
    }
}
