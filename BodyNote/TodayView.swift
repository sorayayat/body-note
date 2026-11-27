import SwiftUI
import BodyNoteCore

struct TodayView: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var composer: ComposerRequest?
    @State private var showingNews = false
    @State private var error: String?

    var body: some View {
        let book = store.book
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                Text("오늘").font(.largeTitle.bold()).foregroundStyle(TrackColor.green)
                    .accessibilityAddTraits(.isHeader)
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

                trainingGroundLink

                if !book.entries.isEmpty {
                    TrainingGrowthLink().buttonStyle(.bordered).controlSize(.large)
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
        .navigationTitle("오늘")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $composer) { ComposerSheet(request: $0) }
        .sheet(isPresented: $showingNews) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        RecoverySettings()
                        Text(book.activeDayCount == 0 ? "첫 재활·훈련 일지를 확정하면 첫 도장과 10 XP를 받아요." :
                                "재활·훈련을 \(book.activeDayCount)일 기록했어요. 현재 \(book.xp) XP예요.")
                    }
                    .padding().frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(TrackColor.cream)
                .navigationTitle("훈련 소식")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { showingNews = false } } }
            }
            .presentationDetents([.medium, .large])
        }
        .saveError($error)
    }

    private var header: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                                                  : AnyLayout(HStackLayout(spacing: 7))
        return layout {
            HStack(spacing: 5) {
                Label("운동일지", systemImage: "dumbbell.fill").font(.title3.bold())
                Spacer(minLength: 2)
                Button {
                    do {
                        try store.update { $0.lastReadTrainingDays = $0.activeDayCount }
                        showingNews = true
                    } catch { self.error = error.localizedDescription }
                } label: {
                    Image(systemName: "bell")
                        .overlay(alignment: .topTrailing) {
                            if store.book.hasTrainingNews { Circle().fill(TrackColor.orange).frame(width: 8, height: 8) }
                        }
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.book.hasTrainingNews ? "새 훈련 소식" : "훈련 소식")
            }
            AthleteLockerLink()
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.bordered)
        }
        .foregroundStyle(TrackColor.green)
    }

    private var trainingGroundLink: some View {
        let book = store.book
        let athlete = book.fieldAthlete
        let source = book.entries.contains(where: { $0.kind != .rest }) ? "최근 훈련" : "다음 기록"
        let appearance = "\(source) · \(athlete.animal.title) · \(athlete.sport.title)"
        let level = "Lv. \(book.level) · \(book.xp) XP"
        return NavigationLink { AdventureView() } label: {
            HStack(spacing: 12) {
                RecordPortrait(athlete: athlete, size: 52, motion: store.receipt?.rewardMotion)
                VStack(alignment: .leading, spacing: 3) {
                    Text("훈련장 보기").font(.headline)
                    Text(appearance).font(.subheadline).foregroundStyle(.secondary)
                    Text(level).font(.caption.bold()).foregroundStyle(TrackColor.green)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.subheadline.weight(.semibold))
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(TrackColor.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("훈련장 보기").accessibilityValue("\(appearance), \(level)")
        .accessibilityIdentifier("training.ground")
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
}

struct AthleteLockerLink: View {
    var body: some View {
        NavigationLink {
            AthleteLockerView()
        } label: {
            Label("선수·스킨 변경", systemImage: "tshirt")
                .frame(minHeight: 44, alignment: .leading).contentShape(Rectangle())
        }
        .accessibilityLabel("선수·스킨 변경")
        .accessibilityIdentifier("athlete.locker")
    }
}

private struct AthleteLockerView: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showingHelp = false
    @State private var error: String?

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 7), count: typeSize.isAccessibilitySize ? 2 : 4)
    }

    var body: some View {
        let book = store.book
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("선수 선택").font(.headline).accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: columns, spacing: 9) {
                    ForEach(Animal.allCases, id: \.self) { animal in
                        KitChoice(animal: animal, sport: book.athlete.sport, title: animal.title,
                                  selected: book.athlete.animal == animal) {
                            do { try store.update { $0.athlete.animal = animal } }
                            catch { self.error = error.localizedDescription }
                        }
                    }
                }
                HStack {
                    Text("다음 기록의 스킨").font(.headline).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button { showingHelp = true } label: {
                        Label("스킨 안내", systemImage: "info.circle").labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                    }
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
                MotionPreview(book: book)
            }
            .padding(16).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
        .background(TrackColor.cream)
        .navigationTitle("선수 라커룸")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $showingHelp) {
            NavigationStack {
                ScrollView {
                    Text("라커룸에서 고른 선수와 스킨으로 다음 기록을 시작해요. 기초 훈련장에는 가장 최근에 확정한 재활·훈련 기록의 모습이 보여요.")
                        .frame(maxWidth: .infinity, alignment: .leading).padding()
                }
                .background(TrackColor.cream)
                .navigationTitle("스킨 안내").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { showingHelp = false } } }
            }
            .presentationDetents([.medium, .large])
        }
        .saveError($error)
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
