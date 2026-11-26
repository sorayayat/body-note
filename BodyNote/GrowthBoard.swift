import SwiftUI
import BodyNoteCore

struct GrowthBoard: View {
    @EnvironmentObject private var store: JournalStore
    @State private var goalReading: PerformanceReading?

    var body: some View {
        let book = store.book
        let cards = book.growthBoard
        Section("기초 훈련장 기록판") {
            if cards.isEmpty {
                Text("같은 운동의 마지막 세트 횟수를 비교해요. 여러 세트라면 세트 간 휴식 시간도 입력해 주세요.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(cards) { card in
                let current = card.current
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        if let athlete = current.recordedAthlete { RecordPortrait(athlete: athlete) }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(current.name).font(.headline)
                            Text(current.condition.label).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("마지막 세트 · \(current.value)회").bold()
                    if let previous = card.previous { readingLink(previous, label: "이전") }
                    readingLink(current, label: "최근")
                    Text(card.feedback).font(.subheadline)
                    Button("이 조건으로 목표 만들기") { goalReading = current }
                        .buttonStyle(.borderless)
                }
                .padding(.vertical, 4)
            }
        }
        .sheet(item: $goalReading) { SkillTargetSheet(reading: $0) }
        SideProgressSection(cards: book.sideProgress())
        if !book.skillGoals.isEmpty {
            Section("숙련 배지") {
                ForEach(book.skillGoals) { goal in
                    let entries = book.entriesContributing(to: goal)
                    NavigationLink {
                        List {
                            Text(goal.condition.label)
                            LabeledContent("시작일", value: goal.start.label)
                            if let first = entries.first { LabeledContent("첫 달성", value: first.day.label) }
                            if entries.count == SkillGoal.requiredSessions, let last = entries.last {
                                LabeledContent("배지 획득", value: last.day.label)
                            }
                            Section("목표를 채운 기록") {
                                ForEach(entries) { entry in
                                    NavigationLink { EntryDetail(id: entry.id) } label: { EntryRow(entry: entry) }
                                }
                            }
                        }.navigationTitle(goal.threshold)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("\(goal.name) · \(goal.threshold)", systemImage: entries.count == SkillGoal.requiredSessions ? "medal.fill" : "medal")
                            Text(entries.count == SkillGoal.requiredSessions ? "배지 획득 · 3/3회" : "\(entries.count)/3회")
                            if let first = entries.first { Text("첫 달성 · \(first.day.label)").font(.caption) }
                        }
                    }
                }
            }
        }
    }

    private func readingLink(_ reading: PerformanceReading, label: String) -> some View {
        NavigationLink(destination: EntryDetail(id: reading.entryID)) {
            Text("\(label) · \(reading.day.label) · \(reading.value)회").font(.caption)
        }.buttonStyle(.borderless)
    }
}

private struct SkillTargetSheet: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss
    let reading: PerformanceReading
    private var draftKey: String { "skill-\(reading.id)" }
    @State private var error: String?

    var body: some View {
        let condition = reading.condition
        let input = store.formField(draftKey, fallback: String(reading.value), error: $error)
        NavigationStack {
            Form {
                Section {
                    Text(reading.name).bold()
                    Text(condition.label)
                    LabeledContent("마지막 세트 목표 (회 이상)") {
                        TextField("횟수", text: input)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing).accessibilityLabel("목표값")
                    }
                } footer: {
                    Text("오늘부터 같은 조건의 목표를 달성한 훈련을 세어요. 서로 다른 훈련 3회에서 달성하면 배지를 받아요.")
                }
            }
            .navigationTitle("숙련 목표 만들기").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("만들기") {
                        do {
                            guard let value = Int(input.wrappedValue) else { throw NotebookError.invalidSkillTarget }
                            try store.update { try $0.addSkillGoal(from: reading, target: value); $0.formInputs?[draftKey] = nil }
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }
                }
            }
            .saveError($error)
        }
    }
}
