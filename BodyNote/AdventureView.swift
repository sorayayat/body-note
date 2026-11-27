import SwiftUI
import BodyNoteCore

struct AdventureView: View {
    @EnvironmentObject private var store: JournalStore
    @State private var reflectionOpen = false
    @State private var goalOpen = false

    var body: some View {
        let book = store.book
        List {
            TrainingScene(book: book).listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            TrainingProgress(book: book).listRowBackground(TrackColor.cream)
            Section {
                AthleteLockerLink()
                TrainingGrowthLink()
            }
            Section("훈련장 마일스톤") {
                milestone("첫 훈련 도장", detail: "재활·훈련 첫 기록", reached: book.activeDayCount >= 1)
                milestone("콘 코스 개방", detail: "서로 다른 3일 기록", reached: book.activeDayCount >= 3)
                milestone("매트 구역 개방", detail: "누적 6일 기록과 한 줄 회고", reached: book.hasMatArea)
                if book.activeDayCount >= 6 {
                    if !book.reflection.isEmpty { Text(book.reflection) }
                    Button(book.reflection.isEmpty ? "한 줄 회고 쓰기" : "회고 수정") { reflectionOpen = true }
                }
            }
            Section("나의 마일스톤") {
                ForEach(book.goals) { goal in
                    let matches = book.entriesContributing(to: goal)
                    NavigationLink {
                        GoalDetail(goal: goal)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Label(goal.title, systemImage: matches.count == goal.targetDays ? "flag.fill" : "flag")
                            Text("\(matches.count) / \(goal.targetDays)일").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Button { goalOpen = true } label: { Label("목표 만들기", systemImage: "plus") }
            }
        }
        .scrollContentBackground(.hidden).background(TrackColor.cream)
        .navigationTitle("기초 훈련장")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $reflectionOpen) {
            NoteSheet("한 줄 회고", key: "reflection", initial: book.reflection) { notebook, value in
                try notebook.saveReflection(value)
            }
        }
        .sheet(isPresented: $goalOpen) { NewGoalSheet() }
    }

    private func milestone(_ name: String, detail: String, reached: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: reached ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(reached ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityValue(reached ? "달성" : "진행 중")
    }
}

private struct NewGoalSheet: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?

    var body: some View {
        let name = store.formField("goal-name", error: $error)
        let days = store.formField("goal-days", fallback: "4", error: $error)
        let target = Binding<Int>(get: { Int(days.wrappedValue) ?? 4 }, set: { days.wrappedValue = String($0) })
        NavigationStack {
            Form {
                Section {
                    TextField("목표 운동 이름", text: name)
                    if !store.book.exerciseNames.isEmpty {
                        Menu("기록한 운동에서 선택") {
                            ForEach(store.book.exerciseNames, id: \.self) { candidate in
                                Button(candidate) { name.wrappedValue = candidate }
                            }
                        }
                    }
                    Stepper("목표 \(target.wrappedValue)일", value: target, in: 1...30)
                } footer: { Text("오늘부터 이 운동을 기록한 날짜를 세어요. 깃발을 누르면 해당 일지를 다시 볼 수 있어요.") }
            }
            .navigationTitle("나의 마일스톤").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("만들기") {
                        do {
                            try store.update {
                                try $0.addGoal(exerciseName: name.wrappedValue, targetDays: target.wrappedValue)
                                $0.formInputs?["goal-name"] = nil
                                $0.formInputs?["goal-days"] = nil
                            }
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }
                    .disabled(Exercise.key(for: name.wrappedValue).isEmpty)
                }
            }
            .saveError($error)
        }
    }
}

private struct GoalDetail: View {
    @EnvironmentObject private var store: JournalStore
    let goal: PersonalGoal

    var body: some View {
        let entries = store.book.entriesContributing(to: goal)
        List {
            Section {
                LabeledContent("시작일", value: goal.start.label)
                LabeledContent("진행", value: "\(entries.count) / \(goal.targetDays)일")
            }
            Section("목표를 채운 기록") {
                if entries.isEmpty { Text("이 운동의 첫 기록을 기다리고 있어요.").foregroundStyle(.secondary) }
                ForEach(entries) { entry in
                    NavigationLink { EntryDetail(id: entry.id) } label: { EntryRow(entry: entry) }
                }
            }
        }
        .navigationTitle(goal.title).navigationBarTitleDisplayMode(.inline)
    }
}
