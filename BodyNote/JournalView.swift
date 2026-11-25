import SwiftUI
import BodyNoteCore

struct JournalView: View {
    enum Filter: String, CaseIterable { case recent = "전체", date = "날짜별", movement = "운동별" }
    @EnvironmentObject private var store: JournalStore
    @State private var filter = Filter.recent
    @State private var date = Date.now

    var body: some View {
        List {
            Picker("일지 보기", selection: $filter) {
                ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            switch filter {
            case .recent:
                entryList(store.book.newestFirst)
            case .date:
                DatePicker("날짜", selection: $date, in: ...Date.now, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                entryList(store.book.newestFirst.filter { $0.day == JournalDay(date) })
            case .movement:
                if store.book.exerciseNames.isEmpty {
                    Text("기록한 운동이 여기에 모여요.").foregroundStyle(.secondary)
                }
                ForEach(store.book.exerciseNames, id: \.self) { name in
                    NavigationLink { ExerciseHistory(name: name) } label: {
                        Label(name, systemImage: "list.bullet.rectangle")
                    }
                }
            }
        }
        .navigationTitle("일지")
    }

    @ViewBuilder
    private func entryList(_ entries: [JournalEntry]) -> some View {
        if entries.isEmpty {
            Text("아직 기록이 없어요.").foregroundStyle(.secondary)
        }
        ForEach(entries) { entry in
            NavigationLink { EntryDetail(id: entry.id) } label: { EntryRow(entry: entry) }
        }
    }
}

private struct SetSummary: View {
    let exercise: Exercise

    var body: some View {
        if let drill = exercise.drill {
            Text(drill.summary).font(.subheadline)
        }
        ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
            HStack {
                Text("\(index + 1)세트").foregroundStyle(.secondary)
                Spacer()
                if set.side != .unspecified { Text(set.side.title) }
                if let weight = set.weightKg { Text("\(weight.formatted()) kg ·") }
                Text("\(set.amount)\(exercise.unit.title)").bold()
            }
            .font(.subheadline)
        }
        if let rest = exercise.restSeconds { LabeledContent("세트 간 휴식", value: "\(rest)초") }
        if !exercise.equipment.isEmpty { Label(exercise.equipment, systemImage: "tag") }
        if !exercise.note.isEmpty { Text(exercise.note).foregroundStyle(.secondary) }
    }
}

struct EntryDetail: View {
    @EnvironmentObject private var store: JournalStore
    let id: UUID
    @State private var composer: ComposerRequest?
    @State private var followUpOpen = false

    var body: some View {
        if let entry = store.book.entries.first(where: { $0.id == id }) {
            List {
                Section {
                    HStack(spacing: 14) {
                        if let athlete = entry.recordedAthlete { RecordPortrait(athlete: athlete, size: 84) }
                        VStack(alignment: .leading, spacing: 4) {
                            Label(entry.kind.title, systemImage: entry.kind.symbol)
                            if let athlete = entry.recordedAthlete {
                                Text("\(athlete.sport.title) 스킨 · \(athlete.animal.title)").font(.headline)
                            }
                            Text(entry.day.label).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    if let sport = entry.sport { LabeledContent("이전 기록 종목", value: sport.title) }
                }
                ForEach(entry.exercises) { exercise in
                    Section {
                        SetSummary(exercise: exercise)
                        NavigationLink("이 운동의 기록 카드") { ExerciseHistory(name: exercise.name) }
                    } header: { Text(exercise.name) }
                }
                if ![entry.before, entry.after, entry.effort, entry.note].allSatisfy(\.isEmpty) {
                    Section("그날의 기록") {
                        if !entry.before.isEmpty { LabeledContent("시작 전", value: entry.before) }
                        if !entry.after.isEmpty { LabeledContent("운동 후", value: entry.after) }
                        if !entry.effort.isEmpty { LabeledContent("난이도", value: entry.effort) }
                        if !entry.note.isEmpty { Text(entry.note) }
                    }
                }
                if entry.day < JournalDay() || !entry.followUp.isEmpty {
                    Section("다음 날 몸 상태") {
                        if !entry.followUp.isEmpty { Text(entry.followUp) }
                        Button(entry.followUp.isEmpty ? "한 줄 덧붙이기" : "다음 날 메모 수정") { followUpOpen = true }
                    }
                }
                Button("오늘 기록으로 가져오기") { composer = ComposerRequest(entry: entry.draftForToday(using: store.book.athlete)) }
            }
            .navigationTitle(entry.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("수정") { composer = ComposerRequest(entry: entry, editing: true) }
                }
            }
            .sheet(item: $composer) { ComposerSheet(request: $0) }
            .sheet(isPresented: $followUpOpen) {
                NoteSheet("다음 날 몸 상태", initial: entry.followUp) { value in
                    try store.update { try $0.setFollowUp(value, for: id) }
                }
            }
        }
    }
}

struct ExerciseHistory: View {
    @EnvironmentObject private var store: JournalStore
    let name: String
    @State private var pinOpen = false
    @State private var composer: ComposerRequest?

    var body: some View {
        let pin = store.book.pinnedNotes[Exercise.key(for: name)] ?? ""
        List {
            Section("다음에 볼 메모") {
                if !pin.isEmpty { Label(pin, systemImage: "pin.fill") }
                Button(pin.isEmpty ? "메모 고정" : "고정 메모 수정") { pinOpen = true }
            }
            ForEach(store.book.history(for: name)) { entry in
                Section {
                    ForEach(entry.exercises.filter { $0.key == Exercise.key(for: name) }) { exercise in
                        SetSummary(exercise: exercise)
                        Button("이 운동만 가져오기") {
                            composer = ComposerRequest(entry: entry.draftForToday(only: exercise, using: store.book.athlete))
                        }
                    }
                    if !entry.followUp.isEmpty { LabeledContent("다음 날", value: entry.followUp) }
                    NavigationLink("일지 전체 보기") { EntryDetail(id: entry.id) }
                } header: { Text(entry.day.label) }
            }
        }
        .navigationTitle(name)
        .sheet(isPresented: $pinOpen) {
            NoteSheet("다음에 볼 메모", initial: pin) { value in try store.update { $0.pin(value, for: name) } }
        }
        .sheet(item: $composer) { ComposerSheet(request: $0) }
    }
}
