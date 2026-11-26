import SwiftUI
import BodyNoteCore

struct ExerciseLibraryView: View {
    var onSelect: ((CatalogExercise) -> Void)? = nil
    @State private var query = ""
    @State private var region: String?
    private let catalog = ExerciseCatalog.bundled

    var body: some View {
        let results = catalog.search(query, region: region)
        List {
            Section("훈련 부위") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                    ForEach(["전체"] + catalog.regions, id: \.self) { label in
                        let value: String? = label == "전체" ? nil : label
                        let selected = region == value
                        Button { region = value } label: {
                            Text(label).font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .foregroundStyle(selected ? Color.white : Color.primary)
                                .background(selected ? TrackColor.green : Color.secondary.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
            Section("동작 \(results.count)개") {
                if results.isEmpty {
                    ContentUnavailableView("찾은 동작이 없어요", systemImage: "magnifyingglass",
                                           description: Text("다른 단어나 훈련 부위를 선택해 보세요."))
                    Button("검색 초기화") { query = ""; region = nil }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 126), spacing: 12)], alignment: .leading, spacing: 14) {
                    ForEach(results) { item in
                        NavigationLink { CatalogExerciseDetail(item: item, onSelect: onSelect) } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                ExerciseArtwork(item: item).frame(height: 100)
                                Text(item.name).font(.headline).foregroundStyle(.primary)
                                Text((item.regions + [item.equipment]).joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("exercise.item." + item.id)
                    }
                }
            }
        }
        .navigationTitle("동작 도감").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "이름, 부위, 도구로 검색")
    }
}

private struct ExerciseArtwork: View {
    let item: CatalogExercise
    var body: some View {
        Image(decorative: "ExerciseArt/\(item.id).png", bundle: ExerciseCatalog.resources)
            .resizable().scaledToFit().padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TrackColor.green, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct CatalogExerciseDetail: View {
    let item: CatalogExercise
    let onSelect: ((CatalogExercise) -> Void)?

    var body: some View {
        List {
            Section {
                ExerciseArtwork(item: item).frame(height: 208)
                Text(item.description)
                if let onSelect {
                    Button { onSelect(item) } label: { Label("이 동작 선택", systemImage: "plus.circle.fill") }
                }
            }
            Section {
                LabeledContent("훈련 부위", value: item.regions.joined(separator: " · "))
                LabeledContent("도구", value: item.equipment)
                LabeledContent("기본 기록 단위", value: item.unit.title)
            }
            Section("그림 출처") {
                Link("Open Exercise Art · Alex Mollard", destination: URL(string: "https://github.com/AlexMollard/Open-Exercise-Art")!)
                Link("CC BY-SA 4.0", destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
            }
        }
        .navigationTitle(item.name).navigationBarTitleDisplayMode(.inline)
    }
}

struct CatalogNameField: View {
    @Binding var exercise: Exercise
    @FocusState private var isTyping: Bool
    @State private var libraryOpen = false
    @State private var maySetUnit: Bool
    let hasTypedNumbers: Bool

    init(exercise: Binding<Exercise>, hasTypedNumbers: Bool) {
        _exercise = exercise
        self.hasTypedNumbers = hasTypedNumbers
        _maySetUnit = State(initialValue: exercise.wrappedValue.isBlankCatalogRow)
    }

    var body: some View {
        TextField("운동 이름", text: $exercise.name).focused($isTyping)
            .accessibilityIdentifier("exercise.name")
        if isTyping && !exercise.key.isEmpty {
            ForEach(ExerciseCatalog.bundled.search(exercise.name).prefix(4)) { item in
                Button { select(item) } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text(item.name)
                        Spacer()
                        Text(item.regions.first ?? "").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        Button {
            isTyping = false
            libraryOpen = true
        } label: {
            Label("부위별 동작 찾기", systemImage: "books.vertical")
        }
        .accessibilityIdentifier("exercise.library")
        .sheet(isPresented: $libraryOpen) {
            NavigationStack {
                ExerciseLibraryView(onSelect: select)
                    .toolbar { ToolbarItem(placement: .cancellationAction) {
                        Button("닫기") { libraryOpen = false }.accessibilityIdentifier("exercise.library.close")
                    } }
            }
        }
        .onChange(of: exercise.sets) { maySetUnit = false }
        .onChange(of: exercise.unit) { maySetUnit = false }
    }

    private func select(_ item: CatalogExercise) {
        exercise.selectFromCatalog(item, useDefaultUnit: maySetUnit && !hasTypedNumbers)
        maySetUnit = false
        isTyping = false
        libraryOpen = false
    }
}
