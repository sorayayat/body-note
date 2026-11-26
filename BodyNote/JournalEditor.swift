import SwiftUI
import BodyNoteCore

struct ComposerRequest: Identifiable {
    let id = UUID()
    let entry: JournalEntry?
    var editing = false
    var routineName: String? = nil
    var resume: WorkoutDraft? = nil
}

struct ComposerSheet: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: JournalEntry?
    private let editing: Bool
    private let routineName: String?
    private let resume: WorkoutDraft?

    init(request: ComposerRequest) {
        _draft = State(initialValue: request.entry)
        editing = request.editing
        routineName = request.routineName
        resume = request.resume
    }

    var body: some View {
        NavigationStack {
            if let resume, resume.purpose == .routine {
                RoutineEditor(.resume(resume))
            } else if let draft {
                JournalEditor(initial: resume ?? store.book.drafts.first { $0.id == draft.id }
                              ?? WorkoutDraft(draft, name: routineName ?? ""),
                              editing: editing || store.book.entries.contains { $0.id == draft.id })
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
    @State private var draft: WorkoutDraft
    private var entry: JournalEntry { draft.entry }
    @State private var error: String?
    @State private var savedRoutineName: String?
    private let editing: Bool
    @State private var discarding = false
    private var fields: Binding<WorkoutDraft> { store.editorFields($draft) }

    init(initial: WorkoutDraft, editing: Bool) {
        _draft = State(initialValue: initial)
        self.editing = editing
    }

    var body: some View {
        Form {
            Section {
                if !draft.name.isEmpty, entry.kind != .rest { LabeledContent("가져온 루틴", value: draft.name) }
                Picker("기록 종류", selection: fields.entry.kind) {
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
                                fields.entry.recordedAthlete.wrappedValue = updated
                            })) {
                                ForEach(TrainingSport.available, id: \.self) { skin in Text(skin.title).tag(skin) }
                            }
                        }
                    }
                }
            }
            if entry.kind != .rest {
                ExerciseSections(exercises: fields.entry.exercises, numbers: fields.numbers, kind: entry.kind)
                Section {
                    NavigationLink {
                        RoutineEditor(.journal(draft)) { savedRoutineName = $0 }
                    } label: {
                        Label("루틴만 저장", systemImage: "bookmark")
                    }
                } footer: {
                    if let savedRoutineName { Text("‘\(savedRoutineName)’ 루틴을 저장했어요.") }
                }
            }
            Section("오늘의 몸 상태") {
                Picker("통증·불편 확인", selection: fields.entry.bodySignal) {
                    Text("기록 안 함").tag(nil as BodySignal?)
                    ForEach(BodySignal.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                }
                if let guidance = entry.bodySignal?.guidance {
                    Label(guidance, systemImage: "cross.case").font(.footnote)
                }
                TextField("시작 전 느낌 (선택)", text: fields.entry.before, axis: .vertical)
                if entry.kind != .rest {
                    TextField("운동 후 느낌 (선택)", text: fields.entry.after, axis: .vertical)
                    Picker("체감 난이도", selection: fields.entry.effort) {
                        Text("선택 안 함").tag("")
                        ForEach(["가벼움", "보통", "힘듦"], id: \.self) { Text($0).tag($0) }
                    }
                }
                TextField("일지 메모 (선택)", text: fields.entry.note, axis: .vertical)
            }
            Section {
                Button(editing ? "수정 내용 확정" : "오늘 기록으로 확정", action: confirm)
                    .frame(maxWidth: .infinity).font(.headline)
                    .accessibilityIdentifier("workout.confirm")
                if store.book.drafts.contains(where: { $0.id == draft.id }) {
                    Button("초안 삭제", role: .destructive) { discarding = true }
                }
            } footer: { DraftSaveStatus() }
        }
        .navigationTitle(editing ? "기록 수정" : "오늘의 기록")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .toolbar { ToolbarItem(placement: .cancellationAction) {
            Button("닫기") {
                do { try store.flushInputs(); dismiss() }
                catch { self.error = error.localizedDescription }
            }
        } }
        .interactiveDismissDisabled(store.inputSaveProblem != nil)
        .confirmationDialog("이 초안을 삭제할까요?", isPresented: $discarding, titleVisibility: .visible) {
            Button("초안 삭제", role: .destructive) {
                do { try store.update { $0.removeDraft(draft.id) }; dismiss() }
                catch { self.error = error.localizedDescription }
            }
        }
        .saveError($error)
    }

    private func confirm() {
        do {
            try store.confirm(draft.resolvedEntry())
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

extension JournalStore {
    /// Write through from the input binding so dismissal or suspension cannot skip a render-cycle observer.
    func editorFields(_ state: Binding<WorkoutDraft>) -> Binding<WorkoutDraft> {
        Binding(get: { state.wrappedValue }, set: { value in
            var next = value
            if next.entry.kind != .rest, next.entry.exercises.isEmpty { next.entry.exercises = [Exercise()] }
            state.wrappedValue = next
            self.keep(next)
        })
    }
}

struct DraftSaveStatus: View {
    @EnvironmentObject private var store: JournalStore
    var body: some View {
        if let problem = store.inputSaveProblem {
            VStack(alignment: .leading) {
                Text("기기에 보관하지 못했어요. \(problem)")
                Button("다시 저장") { try? store.flushInputs() }
            }
        } else {
            Text("작성 중인 내용은 이 기기에 자동으로 보관돼요.")
        }
    }
}

struct ExerciseSections: View {
    @Binding var exercises: [Exercise]
    @Binding var numbers: [String: String]
    let kind: EntryKind
    var showsSessionNotes = true

    var body: some View {
        ForEach($exercises) { $exercise in
            Section {
                ExerciseEditor(exercise: $exercise, numbers: $numbers, kind: kind, showsSessionNotes: showsSessionNotes)
                if exercises.count > 1 || exercise.drill != nil {
                    Button("운동 빼기", role: .destructive) {
                        let id = exercise.id
                        exercises.removeAll { $0.id == id }
                        if exercises.isEmpty { exercises = [Exercise()] }
                    }
                }
            }
        }
        Section {
            Button { exercises.append(Exercise()) } label: { Label("운동 추가", systemImage: "plus") }
        }
    }
}

private struct ExerciseEditor: View {
    @EnvironmentObject private var store: JournalStore
    @Binding var exercise: Exercise
    @Binding var numbers: [String: String]
    let kind: EntryKind
    let showsSessionNotes: Bool
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
            CatalogNameField(exercise: $exercise, hasTypedNumbers: exercise.sets.contains {
                numbers["amount-\($0.id)"] != nil || numbers["weight-\($0.id)"] != nil
            })
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
        if showsSessionNotes {
            TextField("이번 운동 메모 (선택)", text: $exercise.note, axis: .vertical)
        }
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
                    TextField("선택", text: Binding(get: {
                        numbers["weight-\(set.id)"] ?? set.weightKg.map { $0.formatted(.number.grouping(.never)) } ?? ""
                    }, set: { text in
                        numbers["weight-\(set.id)"] = text
                    }))
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("\(number)세트 무게 (kg)")
                    TextField("입력", text: Binding(get: { numbers["amount-\(set.id)"] ?? String(set.amount) },
                                                  set: { numbers["amount-\(set.id)"] = $0 }))
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
            let last = exercise.sets.last
            let added = last?.copied() ?? TrainingSet()
            if let last {
                for prefix in ["amount-", "weight-"] { numbers[prefix + added.id.uuidString] = numbers[prefix + last.id.uuidString] }
            }
            exercise.sets.append(added)
        } label: {
            Label("세트 추가", systemImage: "plus.circle")
        }
        if exercise.unit == .reps && exercise.sets.count > 1 {
            LabeledContent("세트 간 휴식 (초)") {
                TextField("비교하려면 입력", text: Binding(get: {
                    numbers["rest-\(exercise.id)"] ?? exercise.restSeconds.map(String.init) ?? ""
                }, set: { numbers["rest-\(exercise.id)"] = $0 }))
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    .accessibilityLabel("세트 간 휴식 (초)")
            }
        }
    }
}
