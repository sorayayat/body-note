import Foundation

public struct CatalogExercise: Decodable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let regions: [String]
    public let aliases: [String]
    public let keywords: [String]
    public let equipment: String
    public let unit: ExerciseUnit
    public let description: String

    fileprivate func rank(phrase: String, words: [String]) -> Int? {
        let nameKey = ExerciseCatalog.searchKey(name)
        if nameKey == phrase { return 0 }
        let names = [nameKey] + aliases.map(ExerciseCatalog.searchKey)
        if names.contains(phrase) { return 1 }
        if names.contains(where: { $0.hasPrefix(phrase) }) { return 2 }
        if names.contains(where: { $0.contains(phrase) }) { return 3 }
        let fields = names + (regions + keywords + [equipment]).map(ExerciseCatalog.searchKey)
        return words.allSatisfy { word in fields.contains { $0.contains(word) } } ? 4 : nil
    }
}

public struct ExerciseCatalog: Decodable {
    public let regions: [String]
    public let items: [CatalogExercise]
    public static let resources = Bundle.module
    public static let bundled: Self = {
        guard let url = resources.url(forResource: "exercise-catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(Self.self, from: data) else {
            assertionFailure("Missing or invalid bundled exercise catalog")
            return Self(regions: [], items: [])
        }
        return catalog
    }()

    fileprivate static func searchKey(_ text: String) -> String {
        text.precomposedStringWithCompatibilityMapping.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    public func entry(named name: String) -> CatalogExercise? {
        let key = Exercise.key(for: name)
        return items.first { Exercise.key(for: $0.name) == key }
    }

    public func search(_ query: String, region: String? = nil) -> [CatalogExercise] {
        let pool = items.filter { item in region.map { item.regions.contains($0) } ?? true }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return pool }
        let phrase = Self.searchKey(trimmed)
        guard !phrase.isEmpty else { return [] }
        let words = trimmed.split(whereSeparator: \.isWhitespace).map { Self.searchKey(String($0)) }.filter { !$0.isEmpty }
        let matches = pool.enumerated().compactMap { index, item -> (rank: Int, index: Int, item: CatalogExercise)? in
            guard let rank = item.rank(phrase: phrase, words: words) else { return nil }
            return (rank, index, item)
        }
        return matches.sorted { ($0.rank, $0.index) < ($1.rank, $1.index) }.map(\.item)
    }
}

extension Exercise {
    public var isBlankCatalogRow: Bool {
        key.isEmpty && drill == nil && unit == .reps && restSeconds == nil
            && equipment.isEmpty && note.isEmpty && sets.count == 1 && sets[0].amount == 10
            && sets[0].weightKg == nil && sets[0].side == .unspecified
    }

    public mutating func selectFromCatalog(_ item: CatalogExercise, useDefaultUnit: Bool) {
        guard drill == nil else { return }
        name = item.name
        if useDefaultUnit { unit = item.unit }
    }
}
