import SwiftUI
import BodyNoteCore

extension EntryKind {
    var symbol: String {
        switch self {
        case .training: return "dumbbell.fill"
        case .rehab: return "figure.flexibility"
        case .rest: return "moon.stars.fill"
        }
    }
}

extension View {
    func saveError(_ message: Binding<String?>) -> some View {
        alert("저장하지 못했어요", isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            Button("확인") { message.wrappedValue = nil }
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

struct RecordPortrait: View {
    let athlete: Athlete
    var size: CGFloat = 48

    var body: some View {
        AthleteImage(animal: athlete.animal, sport: athlete.sport)
            .padding(3).frame(width: size, height: size)
            .background(TrackColor.cream, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}

struct EntryRow: View {
    let entry: JournalEntry

    var body: some View {
        HStack(spacing: 12) {
            if let athlete = entry.recordedAthlete, entry.kind != .rest {
                RecordPortrait(athlete: athlete)
            } else {
                Image(systemName: entry.kind.symbol)
                    .foregroundStyle(Color.accentColor).frame(width: 48, height: 48)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                Text([entry.day.shortLabel, entry.kind.title, entry.recordedAthlete.map { "\($0.sport.title) 스킨 · \($0.animal.title)" }]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}



struct NoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onSave: (String) throws -> Void
    @State private var text: String
    @State private var error: String?

    init(_ title: String, initial: String, onSave: @escaping (String) throws -> Void) {
        self.title = title
        self.onSave = onSave
        _text = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Form { TextField(title, text: $text, axis: .vertical).lineLimit(3...10) }
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") {
                            do { try onSave(text); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }
                    }
                }
                .saveError($error)
        }
    }
}
