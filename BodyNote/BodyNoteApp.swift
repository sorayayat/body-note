import SwiftUI
import BodyNoteCore

@main
@MainActor
struct BodyNoteApp: App {
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
                        NavigationStack { AdventureView() }.tag(HomeTab.adventure).toolbar(.hidden, for: .tabBar)
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
        }
    }
}

private enum HomeTab: String, CaseIterable {
    case today = "오늘", journal = "일지", adventure = "모험"

    var symbol: String {
        switch self {
        case .today: return "calendar"
        case .journal: return "list.bullet.rectangle"
        case .adventure: return "mountain.2"
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
    private let file: NotebookFile

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = NotebookFile(url: directory.appendingPathComponent("BodyNote/journal.json"))
        reload()
    }

    func reload() {
        do {
            book = try file.load()
            openError = nil
        } catch {
            openError = error.localizedDescription
        }
    }

    func update(_ change: (inout Notebook) throws -> Void) throws {
        if let openError { throw CocoaError(.fileReadUnknown, userInfo: [NSLocalizedDescriptionKey: openError]) }
        var next = book
        try change(&next)
        try file.save(next)
        book = next
    }

    func confirm(_ entry: JournalEntry) throws {
        let previousXP = book.xp
        let previousLevel = book.level
        let previousBadges = book.earnedSkillGoalIDs
        try update { try $0.confirm(entry) }
        var message = "일지를 저장했어요"
        if book.xp > previousXP { message += " · +10 XP" }
        if book.level > previousLevel { message += " · 레벨 \(book.level)!" }
        let earned = book.earnedSkillGoalIDs.subtracting(previousBadges).count
        if earned > 0 { message += " · 숙련 배지 \(earned)개 획득" }
        receipt = Receipt(message: message, didLevelUp: book.level > previousLevel, addedXP: book.xp > previousXP)
    }
}
