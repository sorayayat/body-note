import SwiftUI
import BodyNoteCore

@main
@MainActor
struct BodyNoteApp: App {
    @Environment(\.scenePhase) private var phase
    @StateObject private var store = JournalStore()
    @State private var tab = HomeTab.today

    var body: some Scene {
        WindowGroup {
            Group {
                if let message = store.openError {
                    ContentUnavailableView {
                        Label("일지를 열 수 없어요", systemImage: "book.closed")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("다시 열기") { store.reload() }
                    }
                } else {
                    TabView(selection: $tab) {
                        NavigationStack { TodayView() }.tag(HomeTab.today).toolbar(.hidden, for: .tabBar)
                        NavigationStack { JournalView() }.tag(HomeTab.journal).toolbar(.hidden, for: .tabBar)
                        NavigationStack { CoachView() }.tag(HomeTab.coach).toolbar(.hidden, for: .tabBar)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        HStack(spacing: 8) {
                            ForEach(HomeTab.allCases, id: \.self) { item in
                                Button { tab = item } label: {
                                    VStack(spacing: 3) {
                                        Image(systemName: item.symbol).font(.title3)
                                        Text(item.rawValue).font(.caption.weight(.semibold))
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 47)
                                    .foregroundStyle(tab == item ? TrackColor.green : Color.secondary)
                                    .background(tab == item ? TrackColor.gray : .clear, in: RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain).accessibilityAddTraits(tab == item ? .isSelected : [])
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(TrackColor.cream).overlay(alignment: .top) { Divider() }
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if let problem = store.inputSaveProblem {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("입력 내용을 아직 기기에 쓰지 못했어요.").font(.subheadline.bold())
                                Text(problem).font(.caption)
                                Button("다시 저장") { try? store.flushInputs() }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                            .background(.regularMaterial).accessibilityElement(children: .contain)
                        }
                        if let receipt = store.receipt {
                            Label(receipt.message, systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(.regularMaterial)
                                .accessibilityAddTraits(.isStaticText)
                                .task(id: receipt.id) {
                                    try? await Task.sleep(for: .seconds(4))
                                    guard !Task.isCancelled, store.receipt?.id == receipt.id else { return }
                                    store.receipt = nil
                                }
                        }
                    }
                }
            }
            .tint(TrackColor.green)
            .preferredColorScheme(.light)
            .environmentObject(store)
            .environment(\.locale, Locale(identifier: "ko_KR"))
            .onChange(of: phase, initial: true) { _, state in
                if state == .active, store.openError != nil { store.reload() }
                try? store.flushInputs()
                if state == .active, store.openError == nil { store.refreshReminders() }
            }
        }
    }
}

private enum HomeTab: String, CaseIterable {
    case today = "오늘", journal = "일지", coach = "코치"

    var symbol: String {
        switch self {
        case .today: return "calendar"
        case .journal: return "list.bullet.rectangle"
        case .coach: return "bubble.left.and.bubble.right"
        }
    }
}

@MainActor
final class JournalStore: ObservableObject {
    struct Receipt: Identifiable {
        let id = UUID()
        let message: String
        let didLevelUp: Bool
        let addedXP: Bool
    }

    @Published private(set) var book = Notebook()
    @Published private(set) var openError: String?
    @Published var receipt: Receipt?
    @Published private(set) var sendingCoach = false
    @Published var reminderStatus = ""
    @Published private(set) var inputSaveProblem: String?
    private var pendingInput = false
    private var reminderRevision = 0
    private var updatingReminders = false
    private let topics: any CoachTopicChoosing
    private let repository: any NotebookRepository

    init(topics: any CoachTopicChoosing = DeviceCoachTopics(), repository: (any NotebookRepository)? = nil) {
        self.topics = topics
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var url = directory.appendingPathComponent("BodyNote/journal.json")
        #if DEBUG && targetEnvironment(simulator)
        if let session = ProcessInfo.processInfo.environment["WORKOUT_LOG_UI_TEST_SESSION"],
           let id = UUID(uuidString: session) {
            url = directory.appendingPathComponent("WorkoutLogUITests/\(id.uuidString)/journal.json")
        }
        #endif
        self.repository = repository ?? NotebookFile(url: url)
        reload()
    }

    func reload() {
        do {
            if pendingInput { try flushInputs() }
            book = try repository.load()
            openError = nil
        } catch {
            openError = error.localizedDescription
        }
    }

    func update(_ change: (inout Notebook) throws -> Void) throws {
        if let openError { throw CocoaError(.fileReadUnknown, userInfo: [NSLocalizedDescriptionKey: openError]) }
        book = try repository.applying(to: book, change)
        pendingInput = false
        inputSaveProblem = nil
    }

    /// Draft input remains resumable in memory even if the device is full or locked.
    func flushInputs() throws {
        guard pendingInput else { return }
        do {
            try repository.save(book)
            pendingInput = false
            inputSaveProblem = nil
        } catch {
            inputSaveProblem = error.localizedDescription
            throw error
        }
    }

    func keep(_ draft: WorkoutDraft) {
        guard book.drafts.first != draft else { return }
        book.keepDraft(draft)
        pendingInput = true
        try? flushInputs()
    }

    func formValue(_ key: String, fallback: String = "") -> String {
        book.formInputs?[key] ?? fallback
    }

    func remember(_ text: String, key: String) throws {
        if book.formInputs?[key] != text {
            if book.formInputs == nil { book.formInputs = [:] }
            book.formInputs?[key] = text
            pendingInput = true
        }
        try flushInputs()
    }

    func sendCoach(_ input: String, as athlete: Athlete) async throws {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sendingCoach, !question.isEmpty else { return }
        let key = "chat-" + athlete.animal.rawValue
        sendingCoach = true
        defer { sendingCoach = false }
        let previous = book.coachTurns?.last { $0.athlete.animal == athlete.animal }
        let turn = await TrainingCoach.reply(to: question, athlete: athlete, week: book.tracking(),
                                             previous: previous?.topic, provider: topics, previousTurn: previous)
        try update {
            $0.appendCoachTurn(turn)
            if $0.formInputs?[key] == input { $0.formInputs?[key] = nil }
        }
    }

    func refreshReminders() {
        reminderRevision += 1
        guard !updatingReminders else { return }
        updatingReminders = true
        Task {
            defer { updatingReminders = false }
            var applied = 0
            while applied != reminderRevision {
                applied = reminderRevision
                reminderStatus = await RecoveryNotifications.refresh(book)
            }
        }
    }

    func confirm(_ entry: JournalEntry) throws {
        let previousXP = book.xp
        let previousLevel = book.level
        let previousBadges = book.earnedSkillGoalIDs
        try update { try $0.confirm(entry) }
        refreshReminders()
        var message = "일지를 저장했어요"
        if book.xp > previousXP { message += " · +10 XP" }
        if book.level > previousLevel { message += " · 레벨 \(book.level)!" }
        let earned = book.earnedSkillGoalIDs.subtracting(previousBadges).count
        if earned > 0 { message += " · 숙련 배지 \(earned)개 획득" }
        receipt = Receipt(message: message, didLevelUp: book.level > previousLevel, addedXP: book.xp > previousXP)
    }
}
