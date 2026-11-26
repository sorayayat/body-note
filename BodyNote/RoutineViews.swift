import SwiftUI
import BodyNoteCore

struct RoutineListView: View {
    @EnvironmentObject private var store: JournalStore
    @State private var composer: ComposerRequest?
    @State private var error: String?

    var body: some View {
        List {
            Section {
                NavigationLink { RoutineEditor() } label: { Label("루틴 만들기", systemImage: "plus") }
                if store.book.routines.isEmpty {
                    Text("자주 하는 동작과 세트를 저장해 두면 새 일지를 열 때 바로 불러와요.")
                        .foregroundStyle(.secondary)
                } else {
                    Button("빈 기록으로 시작") { composer = ComposerRequest(entry: store.book.athlete.newEntry()) }
                }
            }
            ForEach(store.book.routines) { routine in
                let isDefault = store.book.defaultRoutineID == routine.id
                Section {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(routine.name).font(.headline)
                        Text(routine.exercises.map { "\($0.name) \($0.sets.count)세트" }.joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button("이 루틴으로 기록") {
                        composer = ComposerRequest(entry: routine.draft(using: store.book.athlete), routineName: routine.name)
                    }
                    NavigationLink("루틴 편집") { RoutineEditor(.saved(routine)) }
                    Button(isDefault ? "기본 루틴 해제" : "기본 루틴으로 지정") {
                        do { try store.update { try $0.setDefaultRoutine(isDefault ? nil : routine.id) } }
                        catch { self.error = error.localizedDescription }
                    }
                } header: {
                    Text(isDefault ? "기본 루틴 · \(routine.kind.title)" : routine.kind.title)
                }
            }
        }
        .navigationTitle("내 루틴")
        .sheet(item: $composer) { ComposerSheet(request: $0) }
        .saveError($error)
    }
}

struct RoutineEditor: View {
    enum Source { case new, entry(JournalEntry), saved(TrainingRoutine), journal(WorkoutDraft), resume(WorkoutDraft) }
    @EnvironmentObject private var store: JournalStore
    private let source: Source
    private let onSaved: ((String) -> Void)?

    init(_ source: Source = .new, onSaved: ((String) -> Void)? = nil) {
        self.source = source
        self.onSaved = onSaved
    }

    private var initial: WorkoutDraft {
        let fresh: WorkoutDraft
        switch source {
        case .resume(let draft): return draft
        case .new: fresh = WorkoutDraft(JournalEntry(), purpose: .routine)
        case .saved(let routine):
            fresh = WorkoutDraft(JournalEntry(kind: routine.kind, exercises: routine.exercises),
                                 purpose: .routine, name: routine.name, routineID: routine.id)
        case .entry(let entry):
            fresh = WorkoutDraft(entry.draftForToday(), purpose: .routine, name: entry.title, parentID: entry.id)
        case .journal(let journal):
            var routine = WorkoutDraft(JournalEntry(kind: journal.entry.kind, exercises: journal.entry.exercises),
                                       purpose: .routine, name: journal.entry.title, parentID: journal.id)
            routine.numbers = journal.numbers
            fresh = routine
        }
        return store.book.drafts.first {
            $0.purpose == .routine && $0.routineID == fresh.routineID && $0.parentID == fresh.parentID
        } ?? fresh
    }

    var body: some View {
        RoutineForm(initial: initial, inSheet: isResumedSheet, onSaved: onSaved)
    }

    private var isResumedSheet: Bool {
        if case .resume = source { return true }
        return false
    }
}

private struct RoutineForm: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkoutDraft
    @State private var error: String?
    @State private var deleting = false
    @State private var deletingRoutine = false
    let inSheet: Bool
    let onSaved: ((String) -> Void)?
    private var fields: Binding<WorkoutDraft> { store.editorFields($draft) }

    init(initial: WorkoutDraft, inSheet: Bool, onSaved: ((String) -> Void)?) {
        _draft = State(initialValue: initial)
        self.inSheet = inSheet
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section {
                TextField("루틴 이름", text: fields.name)
                Picker("기록 종류", selection: fields.entry.kind) {
                    Text("훈련").tag(EntryKind.training)
                    Text("재활").tag(EntryKind.rehab)
                }.pickerStyle(.segmented)
            } footer: {
                if store.book.routines.isEmpty { Text("첫 루틴은 오늘의 기록을 열 때 자동으로 불러와요.") }
            }
            ExerciseSections(exercises: fields.entry.exercises, numbers: fields.numbers,
                             kind: draft.entry.kind, showsSessionNotes: false)
            Section {
                if store.book.drafts.contains(where: { $0.id == draft.id }) {
                    Button("루틴 초안 삭제", role: .destructive) { deletingRoutine = false; deleting = true }
                }
                if draft.routineID != nil {
                    Button("저장된 루틴 삭제", role: .destructive) { deletingRoutine = true; deleting = true }
                }
            } footer: { DraftSaveStatus() }
        }
        .navigationTitle(draft.routineID == nil ? "루틴 만들기" : "루틴 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if inSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        do { try store.flushInputs(); dismiss() } catch { self.error = error.localizedDescription }
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("저장") {
                    do {
                        try store.update { try $0.finishRoutine(draft) }
                        onSaved?(draft.name.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }
            }
        }
        .interactiveDismissDisabled(store.inputSaveProblem != nil)
        .confirmationDialog(deletingRoutine ? "저장된 루틴을 삭제할까요?" : "이 루틴 초안을 삭제할까요?",
                            isPresented: $deleting, titleVisibility: .visible) {
            Button(deletingRoutine ? "저장된 루틴 삭제" : "루틴 초안 삭제", role: .destructive) {
                do {
                    try store.update { book in
                        if deletingRoutine, let id = draft.routineID { book.deleteRoutine(id) }
                        else { book.removeDraft(draft.id) }
                    }
                    dismiss()
                }
                catch { self.error = error.localizedDescription }
            }
            Button("취소", role: .cancel) {}
        }
        .saveError($error)
    }
}
