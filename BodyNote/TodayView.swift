import SwiftUI
import BodyNoteCore

private enum HomeSheet: String, Identifiable {
    case athlete, news, help
    var id: String { rawValue }
}

struct TodayView: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var composer: ComposerRequest?
    @State private var sheet: HomeSheet?
    @State private var error: String?

    var body: some View {
        let book = store.book
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 5) {
                    Image(systemName: "dumbbell.fill")
                    Text("운동일지").fontWeight(.bold)
                    Spacer()
                    Button {
                        do {
                            try store.update { $0.lastReadTrainingDays = $0.activeDayCount }
                            sheet = .news
                        } catch { self.error = error.localizedDescription }
                    } label: {
                        Image(systemName: "bell")
                            .overlay(alignment: .topTrailing) {
                                if book.hasTrainingNews { Circle().fill(TrackColor.orange).frame(width: 8, height: 8) }
                            }
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(book.hasTrainingNews ? "새 훈련 소식" : "훈련 소식")
                    Button { sheet = .athlete } label: { Image(systemName: "person").frame(width: 44, height: 44) }
                        .accessibilityLabel("선수 선택")
                }
                .buttonStyle(.plain).font(.title3).foregroundStyle(TrackColor.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text("오늘").font(.largeTitle.bold()).foregroundStyle(TrackColor.green)
                }
                WeeklyTrackingView()
                if !book.drafts.isEmpty {
                    Text("작성 중").font(.headline)
                    ForEach(book.drafts) { draft in
                        Button {
                            composer = ComposerRequest(entry: draft.entry, resume: draft)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Label(draft.label, systemImage: draft.purpose == .routine ? "bookmark" : "pencil")
                                    if let preview = draft.preview {
                                        Text(preview).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                                Text(draft.purpose == .routine ? "루틴" : "일지").font(.caption)
                                Image(systemName: "chevron.right")
                            }
                        }.buttonStyle(.bordered)
                    }
                    Button("새 운동 기록 시작") {
                        composer = ComposerRequest(entry: book.newTrainingDraft(), routineName: book.defaultRoutine?.name)
                    }
                }
                DisclosureGroup("기초 훈련장 · 스킨") {
                TrainingScene(book: book)
                    .padding(.horizontal, -14)
                TrainingProgress(book: book)
                HStack {
                    Text("다음 기록의 스킨").font(.headline.bold())
                    Spacer()
                    Button { sheet = .help } label: { Image(systemName: "info.circle").frame(width: 44, height: 36) }
                        .accessibilityLabel("스킨 안내")
                }
                LazyVGrid(columns: columns, spacing: 9) {
                    ForEach(TrainingSport.available, id: \.self) { sport in
                        KitChoice(animal: book.athlete.animal, sport: sport, title: sport.title,
                                  selected: book.athlete.sport == sport, showsSportIcon: true) {
                            do { try store.update { $0.athlete.sport = sport } }
                            catch { self.error = error.localizedDescription }
                        }
                    }
                }
                    NavigationLink("모험과 마일스톤") { AdventureView() }.padding(.vertical, 6)
                }.font(.subheadline.weight(.semibold))

                NavigationLink { RoutineListView() } label: {
                    HStack {
                        Label("내 루틴", systemImage: "list.bullet.rectangle")
                        Spacer()
                        if let routine = book.defaultRoutine {
                            Text("기본 · \(routine.name)").font(.subheadline).multilineTextAlignment(.trailing)
                        }
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .frame(minHeight: 36)
                }
                .buttonStyle(.bordered)

                if !book.entries.isEmpty {
                    NavigationLink {
                        List { GrowthBoard() }.navigationTitle("훈련 기록판")
                    } label: {
                        Label("기초 훈련장 기록판", systemImage: "chart.bar").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button { composer = ComposerRequest(entry: nil) } label: {
                        Label("지난 기록 가져오기", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                    Text("최근 기록").font(.headline)
                    ForEach(book.newestFirst.prefix(3)) { entry in
                        NavigationLink { EntryDetail(id: entry.id) } label: { EntryRow(entry: entry) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 7)
            .frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            recordButton
                .padding(.horizontal, 16).padding(.vertical, 8)
                .frame(maxWidth: 600).frame(maxWidth: .infinity)
                .background(TrackColor.cream)
        }
        .background(TrackColor.cream)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $composer) { ComposerSheet(request: $0) }
        .sheet(item: $sheet) { panel in
            NavigationStack {
                VStack(alignment: .leading, spacing: 18) {
                    switch panel {
                    case .athlete:
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("함께 훈련할 선수를 선택하세요.").font(.subheadline)
                                LazyVGrid(columns: columns) {
                                    ForEach(Animal.allCases, id: \.self) { animal in
                                        KitChoice(animal: animal, sport: book.athlete.sport, title: animal.title,
                                                  selected: book.athlete.animal == animal) {
                                            do {
                                                try store.update { $0.athlete.animal = animal }
                                                sheet = nil
                                            } catch { sheet = nil; self.error = error.localizedDescription }
                                        }
                                    }
                                }
                                MotionPreview(book: book)
                            }
                            .padding(3)
                        }
                    case .news:
                        RecoverySettings()
                        Label("훈련 기록판", systemImage: "checkmark.seal")
                        Text(book.activeDayCount == 0 ? "첫 재활·훈련 일지를 확정하면 첫 도장과 10 XP를 받아요." :
                                "재활·훈련을 \(book.activeDayCount)일 기록했어요. 현재 \(book.xp) XP예요.")
                    case .help:
                        Text("새 일지에 입힐 스킨을 고르세요. 훈련을 확정하면 그날의 선수와 스킨이 일지와 훈련장에 보여요.")
                    }
                    if panel != .athlete { Spacer() }
                }
                .padding().frame(maxWidth: .infinity, alignment: .leading).background(TrackColor.cream)
                .navigationTitle(panel == .athlete ? "선수 선택" : panel == .news ? "훈련 소식" : "훈련 스킨")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { sheet = nil } } }
            }
            .presentationDetents(panel == .athlete ? [.large] : [.medium, .large])
        }
        .saveError($error)
    }

    private var recordButton: some View {
        Button {
            if let saved = store.book.drafts.first(where: { $0.purpose == .journal }) {
                composer = ComposerRequest(entry: saved.entry, resume: saved)
            } else {
                composer = ComposerRequest(entry: store.book.newTrainingDraft(), routineName: store.book.defaultRoutine?.name)
            }
        } label: {
            HStack {
                Spacer()
                Image(systemName: "plus.app.fill")
                Text(store.book.drafts.contains { $0.purpose == .journal } ? "작성 중인 기록 이어쓰기"
                     : store.book.entries.isEmpty ? "첫 훈련 기록하기" : "오늘 훈련 기록하기")
                Spacer()
                Image(systemName: "chevron.right").font(.subheadline)
            }
            .font(.headline.bold()).padding(.vertical, 14).padding(.horizontal, 14)
            .foregroundStyle(.white).background(TrackColor.green, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workout.record")
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 7), count: typeSize.isAccessibilitySize ? 2 : 4)
    }
}

private struct MotionPreview: View {
    let book: Notebook
    @State private var selected: TrainingMotion = .stretch
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("동작 미리보기").font(.headline)
            TrainingScene(book: book, previewMotion: selected)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4),
                                     count: typeSize.isAccessibilitySize ? 2 : 5)) {
                ForEach(TrainingMotion.allCases, id: \.self) { motion in
                    Button { selected = motion } label: {
                        VStack(spacing: 3) {
                            AthletePlayer(athlete: book.athlete, motion: motion, isPlaying: selected == motion)
                                .frame(width: 39, height: 44)
                            Text(motion.title).font(.caption)
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(selected == motion ? TrackColor.green.opacity(0.09) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(selected == motion ? TrackColor.green : .clear)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(motion.title)
                    .accessibilityAddTraits(selected == motion ? .isSelected : [])
                }
            }
        }
    }
}
