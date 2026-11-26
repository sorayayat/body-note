import SwiftUI
import BodyNoteCore

struct SideProgressSection: View {
    let cards: [SideProgressCard]
    let showsExerciseName: Bool
    @State private var selected: SideReading?
    @Environment(\.dynamicTypeSize) private var typeSize

    init(cards: [SideProgressCard], showsExerciseName: Bool = true) {
        self.cards = cards
        self.showsExerciseName = showsExerciseName
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .topLeading),
                            count: typeSize.isAccessibilitySize ? 1 : 2)
        Section {
            if cards.isEmpty {
                Text("세트 방향을 왼쪽이나 오른쪽으로 기록하면 여기에 모여요.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(cards) { card in
                VStack(alignment: .leading, spacing: 8) {
                    if showsExerciseName { Text(card.name).font(.headline) }
                    let load = card.id.weightKg.map { "\($0.formatted()) kg" } ?? "중량 미입력"
                    Text([card.equipment, load].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(showsExerciseName ? .caption : .subheadline.weight(.semibold))
                    LazyVGrid(columns: columns, alignment: .leading) {
                        SideHistoryTile(side: .left, history: card.left, unit: card.id.unit) { selected = $0 }
                        SideHistoryTile(side: .right, history: card.right, unit: card.id.unit) { selected = $0 }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("좌우 변화")
        } footer: {
            if !cards.isEmpty {
                Text("같은 도구·중량·단위에서 방향별 마지막 세트를 비교해요. 수치를 누르면 그날의 일지가 열려요.")
            }
        }
        .sheet(item: $selected) { reading in
            NavigationStack {
                EntryDetail(id: reading.entryID)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { selected = nil } } }
            }
        }
    }
}

private struct SideHistoryTile: View {
    let side: BodySide
    let history: SideHistory
    let unit: ExerciseUnit
    let open: (SideReading) -> Void

    private var changeLabel: String {
        guard let change = history.change else { return history.latest == nil ? "기록 없음" : "첫 기록" }
        if change == 0 { return "동일" }
        return "\(change > 0 ? "+" : "")\(change)\(unit.title)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(side.title).font(.subheadline.weight(.semibold))
            Text(changeLabel).font(.headline.monospacedDigit())
            if let latest = history.latest {
                Divider()
                if let previous = history.previous { readingLink(previous, label: "이전") }
                readingLink(latest, label: "최근")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(9)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func readingLink(_ reading: SideReading, label: String) -> some View {
        Button { open(reading) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(label) \(reading.amount)\(unit.title)").font(.subheadline.weight(.medium)).underline()
                Text(reading.day.label).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(side.title) \(label) \(reading.amount)\(unit.title), \(reading.day.label) 일지")
    }
}
