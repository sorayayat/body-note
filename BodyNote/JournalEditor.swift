import SwiftUI
import BodyNoteCore

struct ComposerRequest: Identifiable {
    let id = UUID()
    let entry: JournalEntry?
    var editing = false
}

struct ComposerSheet: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: JournalEntry?
    private let editing: Bool

    init(request: ComposerRequest) {
        _draft = State(initialValue: request.entry)
        editing = request.editing
    }

    var body: some View {
        NavigationStack {
            if let draft {
                JournalEditor(entry: draft, editing: editing)
            } else {
                List(store.book.newestFirst) { entry in
                    Button { self.draft = entry.draftForToday(using: store.book.athlete) } label: { EntryRow(entry: entry) }
                }
                .navigationTitle("지난 기록 가져오기")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
            }
        }
    }
}

struct JournalEditor: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss
    @State private var entry: JournalEntry
    @State private var error: String?
    private let editing: Bool

    init(entry: JournalEntry, editing: Bool) {
        _entry = State(initialValue: entry)
        self.editing = editing
    }

    var body: some View {
        Form {
            Section {
                Picker("기록 종류", selection: $entry.kind) {
                    ForEach(EntryKind.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if entry.kind != .rest {
                    let athlete = entry.appearance(using: store.book.athlete)
                    HStack(spacing: 12) {
                        RecordPortrait(athlete: athlete, size: 64)
                        VStack(alignment: .leading) {
                            Text(athlete.animal.title).font(.headline)
                            Picker("이 기록의 스킨", selection: Binding(get: { athlete.sport }, set: { skin in
                                var updated = athlete
                                updated.sport = skin
                                entry.recordedAthlete = updated
                            })) {
                                ForEach(TrainingSport.available, id: \.self) { skin in Text(skin.title).tag(skin) }
                            }
                        }
                    }
                }
            }
            if entry.kind != .rest {
                ForEach($entry.exercises) { $exercise in
                    Section {
                        ExerciseEditor(exercise: $exercise, kind: entry.kind)
                        if entry.exercises.count > 1 || exercise.drill != nil {
                            Button("운동 빼기", role: .destructive) {
                                let id = exercise.id
                                entry.exercises.removeAll { $0.id == id }
                                if entry.exercises.isEmpty { entry.exercises = [Exercise()] }
                            }
                        }
                    }
                }
                Section {
                    Button { entry.exercises.append(Exercise()) } label: { Label("운동 추가", systemImage: "plus") }
                }
            }
            Section("오늘의 몸 상태") {
                TextField("시작 전 느낌 (선택)", text: $entry.before, axis: .vertical)
                if entry.kind != .rest {
                    TextField("운동 후 느낌 (선택)", text: $entry.after, axis: .vertical)
                    Picker("체감 난이도", selection: $entry.effort) {
                        Text("선택 안 함").tag("")
                        ForEach(["가벼움", "보통", "힘듦"], id: \.self) { Text($0).tag($0) }
                    }
                }
                TextField("일지 메모 (선택)", text: $entry.note, axis: .vertical)
            }
            Section {
                Button(editing ? "수정 내용 확정" : "오늘 기록으로 확정", action: confirm)
                    .frame(maxWidth: .infinity).font(.headline)
            }
        }
        .navigationTitle(editing ? "기록 수정" : "오늘의 기록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
        .onChange(of: entry.kind) { _, kind in
            if kind != .rest, entry.exercises.isEmpty { entry.exercises = [Exercise()] }
        }
        .saveError($error)
    }

    private func confirm() {
        do {
            try store.confirm(entry)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct ExerciseEditor: View {
    @EnvironmentObject private var store: JournalStore
    @Binding var exercise: Exercise
    let kind: EntryKind
    @State private var enteringSides = false

    private var amountLabel: String {
        switch exercise.unit {
        case .reps: return "횟수 (회)"
        case .seconds, .minutes: return "시간 (\(exercise.unit.title))"
        case .meters: return "거리 (m)"
        }
    }

    var body: some View {
        if exercise.drill == nil {
            CatalogNameField(exercise: $exercise)
        } else {
            TextField("운동 이름", text: $exercise.name)
        }
        if let pin = store.book.pinnedNotes[exercise.key] {
            Label(pin, systemImage: "pin.fill").font(.subheadline).foregroundStyle(Color.accentColor)
        }
        if let drill = exercise.drill {
            LabeledContent("이전 종목 기록", value: drill.summary)
        } else {
            setFields
        }
        TextField("이번 운동 메모 (선택)", text: $exercise.note, axis: .vertical)
    }

    @ViewBuilder private var setFields: some View {
        let showSides = enteringSides || kind == .rehab || exercise.sets.contains { $0.side != .unspecified }
        TextField("도구 · 밴드 색 (선택)", text: $exercise.equipment)
        Picker("기록 단위", selection: $exercise.unit) {
            ForEach(ExerciseUnit.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        if !showSides {
            Button { enteringSides = true } label: { Label("좌우 나눠 기록", systemImage: "arrow.left.and.right") }
        }
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                Text("세트")
                Text("무게 (kg)")
                Text(amountLabel)
            }
            .font(.caption.bold()).foregroundStyle(.secondary)
            ForEach($exercise.sets) { $set in
                let number = (exercise.sets.firstIndex { $0.id == set.id } ?? 0) + 1
                GridRow {
                    Text("\(number)세트").font(.subheadline.weight(.semibold))
                    TextField("선택", value: $set.weightKg, format: .number)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("\(number)세트 무게 (kg)")
                    TextField("입력", value: $set.amount, format: .number)
                        .keyboardType(.numberPad)
                        .accessibilityLabel("\(number)세트 \(amountLabel)")
                    if exercise.sets.count > 1 {
                        Button(role: .destructive) {
                            let id = set.id
                            exercise.sets.removeAll { $0.id == id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless).accessibilityLabel("\(number)세트 빼기")
                    }
                }
                if showSides {
                    Picker("\(number)세트 방향", selection: $set.side) {
                        ForEach(BodySide.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .textFieldStyle(.roundedBorder)
        .monospacedDigit()
        .padding(.vertical, 4)
        Button {
            exercise.sets.append(exercise.sets.last?.copied() ?? TrainingSet())
        } label: {
            Label("세트 추가", systemImage: "plus.circle")
        }
        if exercise.unit == .reps && exercise.sets.count > 1 {
            LabeledContent("세트 간 휴식 (초)") {
                TextField("비교하려면 입력", value: $exercise.restSeconds, format: .number)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    .accessibilityLabel("세트 간 휴식 (초)")
            }
        }
    }
}
