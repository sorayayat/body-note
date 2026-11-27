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
    var motion: TrainingMotion? = nil

    var body: some View {
        AthletePlayer(athlete: athlete, motion: motion ?? .idle, isPlaying: motion != nil)
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
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss
    let title: String
    let key: String
    let onSave: (inout Notebook, String) throws -> Void
    let initial: String
    @State private var error: String?

    init(_ title: String, key: String, initial: String, onSave: @escaping (inout Notebook, String) throws -> Void) {
        self.title = title
        self.key = key
        self.onSave = onSave
        self.initial = initial
    }

    var body: some View {
        let input = store.formField(key, fallback: initial, error: $error)
        NavigationStack {
            Form { TextField(title, text: input, axis: .vertical).lineLimit(3...10) }
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") {
                            do {
                                let value = input.wrappedValue
                                try store.update { book in try onSave(&book, value); book.formInputs?[key] = nil }
                                dismiss()
                            }
                            catch { self.error = error.localizedDescription }
                        }
                    }
                }
                .saveError($error)
        }
    }
}

extension JournalStore {
    func formField(_ key: String, fallback: String = "", error message: Binding<String?>) -> Binding<String> {
        Binding(get: { self.formValue(key, fallback: fallback) }, set: { value in
            do { try self.remember(value, key: key) } catch { message.wrappedValue = error.localizedDescription }
        })
    }
}
