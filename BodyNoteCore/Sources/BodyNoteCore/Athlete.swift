import Foundation

public enum Animal: String, Codable, CaseIterable {
    case cat, dog, rabbit, raccoon

    public var title: String {
        switch self {
        case .cat: return "고양이"
        case .dog: return "강아지"
        case .rabbit: return "토끼"
        case .raccoon: return "너구리"
        }
    }
}

public enum TrainingSport: String, Codable, CaseIterable {
    case running, fieldHockey, weightTraining, basic
    case soccer, basketball  // Stored in journals from the original sport catalog.

    // This order also matches the rows in the shared motion artwork.
    public static let available: [Self] = [.running, .fieldHockey, .weightTraining, .basic]

    public var isAvailable: Bool { Self.available.contains(self) }

    public var title: String {
        switch self {
        case .running: return "러닝"
        case .fieldHockey: return "필드하키"
        case .weightTraining: return "웨이트"
        case .basic: return "기초 재활"
        case .soccer: return "축구"
        case .basketball: return "농구"
        }
    }
}

public struct Athlete: Codable, Equatable {
    public var animal: Animal = .cat
    private var kit: TrainingSport = .running

    public var sport: TrainingSport {
        get { kit }
        set { kit = newValue.isAvailable ? newValue : .running }
    }

    private enum CodingKeys: String, CodingKey {
        case animal
        case kit = "sport"
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        animal = try values.decode(Animal.self, forKey: .animal)
        sport = try values.decode(TrainingSport.self, forKey: .kit)
    }

    public func newEntry() -> JournalEntry {
        var entry = JournalEntry()
        entry.recordedAthlete = self
        return entry
    }
}
