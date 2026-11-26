import Foundation
import XCTest
@testable import BodyNoteCore

final class WorkoutMVPTests: XCTestCase {
    private let zone = TimeZone(identifier: "America/Los_Angeles")!
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        return cal
    }
    // This week includes the autumn clock change in Los Angeles.
    private func date(_ delta: Int, hour: Int = 12) -> Date {
        let start = calendar.date(from: DateComponents(year: 2025, month: 11, day: 4, hour: hour))!
        return calendar.date(byAdding: .day, value: delta, to: start)!
    }
    private func workout(_ name: String = "밴드 로우", sets: Int = 1) -> JournalEntry {
        JournalEntry(exercises: [Exercise(name: name, sets: (0..<sets).map { _ in TrainingSet(amount: 8, weightKg: 5) })])
    }
    private func saveReload(_ book: Notebook) throws -> Notebook {
        let location = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: location) }
        let file = NotebookFile(url: location.appendingPathComponent("journal.json"))
        try file.save(book)
        return try file.load()
    }

    func testIncompleteEntryAndIndependentRoutineSurviveReopenWithoutReward() throws {
        var journal = WorkoutDraft(workout())
        let set = journal.entry.exercises[0].sets[0]
        journal.entry.note = "설명을 보고 이어쓰기"
        journal.numbers = ["weight-\(set.id)": "12.", "amount-\(set.id)": ""]
        var routine = WorkoutDraft(workout("플랭크"), purpose: .routine, name: "아침", parentID: journal.id)
        routine.entry.exercises[0].unit = .seconds
        var book = Notebook()
        book.keepDraft(journal)
        book.keepDraft(routine)
        book = try saveReload(book)
        XCTAssertEqual(book.drafts, [routine, journal])
        XCTAssertEqual(book.xp, 0)
        XCTAssertEqual(book.tracking(at: date(0), zone: zone).sets, 0)
        XCTAssertThrowsError(try journal.resolvedEntry())
        try book.finishRoutine(routine)
        XCTAssertEqual(book.drafts, [journal])
        XCTAssertEqual(book.routines.count, 1)
        journal.numbers["amount-\(set.id)"] = "6"
        journal.numbers["weight-\(set.id)"] = "12,5"
        book.keepDraft(journal)
        try book.confirm(journal.resolvedEntry(), at: date(0), timeZone: zone)
        book = try saveReload(book)
        XCTAssertTrue(book.drafts.isEmpty)
        let confirmed = try XCTUnwrap(book.entries.first)
        XCTAssertEqual(confirmed.id, journal.id)
        XCTAssertEqual(confirmed.note, "설명을 보고 이어쓰기")
        XCTAssertEqual(confirmed.exercises[0].sets[0].weightKg, 12.5)
        XCTAssertEqual(confirmed.exercises[0].sets[0].amount, 6)
        XCTAssertEqual(book.xp, 10)
        try book.confirm(confirmed, at: date(1), timeZone: zone)
        XCTAssertEqual(book.entries.count, 1)
        XCTAssertEqual(book.entries.first?.day, JournalDay(date(0), timeZone: zone))
    }

    func testDraftShelfDistinguishesTwoUnfinishedWeightsForTheSameExercise() {
        XCTAssertNil(WorkoutDraft(JournalEntry()).preview)
        var left = WorkoutDraft(workout())
        var right = WorkoutDraft(workout())
        left.numbers["weight-\(left.entry.exercises[0].sets[0].id)"] = "33."
        right.numbers["weight-\(right.entry.exercises[0].sets[0].id)"] = "44"
        XCTAssertEqual(left.label, right.label)
        XCTAssertTrue(left.preview?.contains("33. kg") == true)
        XCTAssertTrue(right.preview?.contains("44 kg") == true)
    }

    func testEditAndCopyKeepOriginalDateLaterFollowUpAndSeparateIDs() throws {
        var book = Notebook()
        var original = workout()
        original.bodySignal = .stopped
        try book.confirm(original, at: date(-2), timeZone: zone)
        var edit = WorkoutDraft(try XCTUnwrap(book.entries.first))
        edit.entry.exercises[0].sets[0].amount = 11
        let copy = WorkoutDraft(edit.entry.draftForToday())
        XCTAssertNil(copy.entry.bodySignal)
        XCTAssertNotEqual(copy.id, edit.id)
        book.keepDraft(edit)
        book.keepDraft(copy)
        try book.setFollowUp("다음 날 메모", for: original.id, today: JournalDay(date(0), timeZone: zone))
        book = try saveReload(book)
        XCTAssertEqual(book.entries.first?.exercises[0].sets[0].amount, 8)
        try book.confirm(edit.resolvedEntry(), at: date(0), timeZone: zone)
        XCTAssertEqual(book.entries.first?.exercises[0].sets[0].amount, 11)
        XCTAssertEqual(book.entries.first?.followUp, "다음 날 메모")
        XCTAssertEqual(book.entries.first?.recordedAt, date(-2))
        XCTAssertEqual(book.drafts.map(\.id), [copy.id])
        book.removeDraft(copy.id)
        XCTAssertEqual(book.entries.count, 1)
    }

    func testWeekUsesLocalCalendarDistinctDaysAndOnlyConfirmedSessions() throws {
        var book = Notebook()
        for offset in [-14,-13,-7,-7,-6,-2,0,0,1] {
            try book.confirm(workout(sets: 2), at: date(offset), timeZone: zone)
        }
        try book.confirm(JournalEntry(kind: .rest), at: date(-1), timeZone: zone)
        book.keepDraft(WorkoutDraft(workout(sets: 9)))
        let week = book.tracking(at: date(0), zone: zone)
        XCTAssertEqual(week.days.map(\.day), (-6...0).map { JournalDay(date($0), timeZone: zone) })
        XCTAssertEqual(week.activeDays, 3)
        XCTAssertEqual(week.sessions, 4)
        XCTAssertEqual(week.sets, 8)
        XCTAssertEqual(week.previousActiveDays, 2)
        XCTAssertTrue(week.days[5].rested)
        XCTAssertTrue(week.cues.isEmpty)
    }

    func testRestPromptAndNotificationHaveARecordAndOneLocalDeadline() throws {
        var book = Notebook()
        for offset in -2...0 { try book.confirm(workout(), at: date(offset), timeZone: zone) }
        let cue = try XCTUnwrap(book.tracking(at: date(0), zone: zone).cues.first)
        XCTAssertEqual(cue.kind, .rest)
        XCTAssertEqual(cue.entryID, book.entries.last?.id)
        XCTAssertEqual(cue.reminderDate(after: date(0), zone: zone), date(1, hour: 9))
        XCTAssertNil(cue.reminderDate(after: date(1, hour: 9), zone: zone))
        try book.confirm(JournalEntry(kind: .rest), at: date(0, hour: 18), timeZone: zone)
        XCTAssertFalse(book.tracking(at: date(0, hour: 19), zone: zone).cues.contains { $0.kind == .rest })
    }

    func testCheckInPriorityResolutionAndExpiry() throws {
        var book = Notebook()
        for offset in -2 ... -1 { try book.confirm(workout(), at: date(offset), timeZone: zone) }
        var entry = workout()
        entry.bodySignal = .worsening
        try book.confirm(entry, at: date(0), timeZone: zone)
        XCTAssertEqual(book.tracking(at: date(0), zone: zone).cues.map(\.kind), [.discomfort, .rest])
        XCTAssertEqual(book.tracking(at: date(0), zone: zone).cues.first?.entryID, entry.id)
        XCTAssertTrue(book.tracking(at: date(8), zone: zone).cues.isEmpty)
        var recovered = JournalEntry(kind: .rest)
        recovered.bodySignal = .comfortable
        try book.confirm(recovered, at: date(1), timeZone: zone)
        XCTAssertTrue(book.tracking(at: date(1), zone: zone).cues.isEmpty)
    }

    func testLongStreakCrossesTheWeeklyChartAndEndsAfterAMissingDay() throws {
        var book = Notebook()
        for offset in -10 ... -1 { try book.confirm(workout(), at: date(offset), timeZone: zone) }
        let today = book.tracking(at: date(0), zone: zone)
        XCTAssertEqual(today.activeDays, 6)
        XCTAssertTrue(try XCTUnwrap(today.cues.first { $0.kind == .rest }).title.contains("10일"))
        XCTAssertFalse(book.tracking(at: date(1), zone: zone).cues.contains { $0.kind == .rest })
    }

    func testChatWorksOfflineAndKeepsAnimalAndTypedQuestionAfterReload() async throws {
        var book = Notebook()
        book.athlete.animal = .raccoon
        try book.confirm(workout(sets: 3), at: date(0), timeZone: zone)
        let week = book.tracking(at: date(0), zone: zone)
        let summary = await TrainingCoach.reply(to: "최근 운동을 돌아볼래", athlete: book.athlete, week: week, previous: nil)
        XCTAssertEqual(summary.topic, .review)
        XCTAssertTrue(summary.answer.contains("3세트"))
        XCTAssertFalse(summary.usedModel)
        let first = await TrainingCoach.reply(to: "경기 전에 긴장돼", athlete: book.athlete, week: week, previous: nil)
        let second = await TrainingCoach.reply(to: "첫 패스 생각이 나", athlete: book.athlete, week: week, previous: first.topic)
        XCTAssertEqual(second.topic, .focus)
        XCTAssertNotEqual(first.answer, second.answer)
        book.appendCoachTurn(second)
        book.formInputs = ["chat-raccoon": "아직 안 보낸 말", "follow-test": "아침 메모"]
        book = try saveReload(book)
        XCTAssertEqual(book.coachTurns?.first?.athlete.animal, .raccoon)
        XCTAssertEqual(book.formInputs?["chat-raccoon"], "아직 안 보낸 말")
    }

    func testRequestsForWorkoutLogsUseConfirmedTotalsEvenWithAMisclassifiedTopic() async throws {
        struct AlwaysConfidence: CoachTopicChoosing {
            func topic(for question: String, previous: CoachTopic?) async -> CoachTopic? { .confidence }
        }
        var book = Notebook()
        try book.confirm(workout(sets: 3), at: date(0), timeZone: zone)
        book.keepDraft(WorkoutDraft(workout(sets: 7)))
        let week = book.tracking(at: date(0), zone: zone)
        for provider in [nil, AlwaysConfidence()] as [(any CoachTopicChoosing)?] {
            for message in ["최근 운동 기록 알려줘", "운동기록을 좀 보여줘", "이번 주 운동 횟수가 궁금해"] {
                let turn = await TrainingCoach.reply(to: message, athlete: book.athlete, week: week,
                                                     previous: .confidence, provider: provider)
                XCTAssertEqual(turn.topic, .review, message)
                XCTAssertTrue(turn.answer.contains("1회 운동했고 3세트"), message)
                XCTAssertFalse(turn.usedModel, message)
            }
        }
    }

    func testEmotionsAboutTheLogAndSafetySignalsKeepTheirOwnTopics() async {
        struct AlwaysReview: CoachTopicChoosing {
            func topic(for question: String, previous: CoachTopic?) async -> CoachTopic? { .review }
        }
        let messages: [(String, CoachTopic)] = [
            ("동기가 안 생겨", .confidence), ("운동 기록을 보니 속상해", .confidence),
            ("운동 기록을 보니 속상해. 자신감 회복할 방법을 알려줘", .confidence),
            ("통증이 있는데 최근 운동 기록 알려줘", .discomfort), ("죽고 싶어. 운동 기록 알려줘", .safety)
        ]
        for (message, expected) in messages {
            let turn = await TrainingCoach.reply(to: message, athlete: Athlete(), week: Notebook().tracking(),
                                                 previous: .review, provider: AlwaysReview())
            XCTAssertEqual(turn.topic, expected, message)
        }
    }

    func testSafetyRoutingCannotBeOverriddenByTopicProvider() async {
        struct AlwaysFocus: CoachTopicChoosing {
            func topic(for question: String, previous: CoachTopic?) async -> CoachTopic? { .focus }
        }
        let week = Notebook().tracking()
        for (question, topic) in [("훈련 중 무릎이 아파", CoachTopic.discomfort), ("죽고 싶어", .safety),
                                  ("공황 증상이 자주 와", .support), ("운동을 몇 세트 했지?", .review)] {
            let turn = await TrainingCoach.reply(to: question, athlete: Athlete(), week: week, previous: .confidence, provider: AlwaysFocus())
            XCTAssertEqual(turn.topic, topic)
            XCTAssertFalse(turn.usedModel)
        }
    }

    func testOnlySportsReflectionsUseGeneratedContentAndOnlyFromTheSameAnimal() async throws {
        actor Model: CoachTopicChoosing {
            var requests: [CoachReflectionRequest] = []
            func topic(for question: String, previous: CoachTopic?) async -> CoachTopic? { .focus }
            func reflection(for request: CoachReflectionRequest) async -> String? {
                requests.append(request)
                return "첫 패스를 떠올렸구나. 그때 어디에 집중하고 싶어?"
            }
        }
        let model = Model(), week = Notebook().tracking()
        var athlete = Athlete()
        athlete.animal = .rabbit
        let first = await TrainingCoach.reply(to: "경기가 떨려", athlete: athlete, week: week, previous: nil, provider: model)
        XCTAssertTrue(first.usedModel && first.generatedReflection)
        let next = await TrainingCoach.reply(to: "첫 패스가 걱정돼", athlete: athlete, week: week, previous: first.topic,
                                             provider: model, previousTurn: first)
        athlete.animal = .dog
        _ = await TrainingCoach.reply(to: "집중할래", athlete: athlete, week: week, previous: nil,
                                      provider: model, previousTurn: next)
        let recovery = await TrainingCoach.reply(to: "오늘은 쉬어도 될까", athlete: athlete, week: week, previous: .focus,
                                                 provider: model, previousTurn: next)
        let requests = await model.requests
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(requests[1].previousQuestion, first.question)
        XCTAssertEqual(requests[1].previousAnswer, first.answer)
        XCTAssertNil(requests[2].previousQuestion)
        XCTAssertNil(requests[2].previousAnswer)
        XCTAssertEqual(recovery.topic, .recovery)
        XCTAssertFalse(recovery.generatedReflection)
        let decoded = try JSONDecoder().decode(CoachTurn.self, from: JSONEncoder().encode(next))
        XCTAssertEqual(decoded, next)
    }

    func testUnusableGeneratedReflectionFallsBackToLocalCoaching() async {
        struct EmptyReply: CoachTopicChoosing {
            func topic(for question: String, previous: CoachTopic?) async -> CoachTopic? { .confidence }
            func reflection(for request: CoachReflectionRequest) async -> String? { "   " }
        }
        let turn = await TrainingCoach.reply(to: "자신감이 없어", athlete: Athlete(), week: Notebook().tracking(),
                                             previous: nil, provider: EmptyReply())
        XCTAssertEqual(turn.topic, .confidence)
        XCTAssertFalse(turn.generatedReflection)
        XCTAssertFalse(turn.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testRepositoryFailureKeepsDraftAndRetryStoresOneCompleteSession() throws {
        enum Failure: Error { case noSpace }
        final class MemoryDisk: NotebookRepository {
            var snapshot = Notebook()
            var failing = false
            func load() throws -> Notebook { snapshot }
            func save(_ notebook: Notebook) throws {
                if failing { throw Failure.noSpace }
                snapshot = notebook
            }
        }
        let disk = MemoryDisk()
        let raw = WorkoutDraft(workout())
        var current = try disk.applying(to: disk.load()) { $0.keepDraft(raw) }
        disk.failing = true
        XCTAssertThrowsError(try disk.applying(to: current) { _ in })
        XCTAssertThrowsError(try disk.applying(to: current) { try $0.confirm(raw.resolvedEntry()) })
        XCTAssertEqual(disk.snapshot, current)
        XCTAssertEqual(current.drafts.first, raw)
        XCTAssertTrue(current.entries.isEmpty)
        disk.failing = false
        current = try disk.applying(to: current) { try $0.confirm(raw.resolvedEntry()) }
        XCTAssertEqual(current.entries.map(\.id), [raw.id])
        XCTAssertTrue(current.drafts.isEmpty)
        XCTAssertEqual(try disk.load(), current)
    }

    func testFirstWriteUpgradesV1AndAnUnknownVersionRemainsUntouched() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let old = Data(#"{"version":1,"notebook":{"entries":[],"pinnedNotes":{},"goals":[],"reflection":""}}"#.utf8)
        try old.write(to: url)
        let file = NotebookFile(url: url)
        let loaded = try file.load()
        XCTAssertEqual(try Data(contentsOf: url), old)
        let draft = WorkoutDraft(workout())
        _ = try file.applying(to: loaded) { $0.keepDraft(draft) }
        let data = try Data(contentsOf: url)
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(document["version"] as? Int, 3)
        XCTAssertEqual(try file.load().drafts.first, draft)
        let future = Data(#"{"version":99,"notebook":{"newLayout":[]}}"#.utf8)
        try future.write(to: url)
        XCTAssertThrowsError(try file.load()) { error in
            guard case NotebookError.unsupportedFile = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertEqual(try Data(contentsOf: url), future)
    }
}
