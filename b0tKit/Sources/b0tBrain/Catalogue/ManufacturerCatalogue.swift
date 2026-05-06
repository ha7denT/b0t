import Foundation

/// The Phase-4 catalogue: all Manufacturers + all BotModels in one JSON file.
/// Phase 4 ships only Wundercog/Hilfer; Phase 6 expansions add JSON entries.
public struct ManufacturerCatalogue: Sendable {
    public let manufacturers: [Manufacturer]
    public let models: [BotModel]
}

extension ManufacturerCatalogue: Decodable {
    enum CodingKeys: String, CodingKey {
        case manufacturers, models
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.manufacturers = try c.decode([Manufacturer].self, forKey: .manufacturers)
        self.models = try c.decode([BotModel].self, forKey: .models)
    }
}

extension ManufacturerCatalogue {
    /// Loads + decodes the catalogue from a JSON file URL.
    public static func load(from url: URL) throws -> ManufacturerCatalogue {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ManufacturerCatalogue.self, from: data)
    }

    /// Returns the starter Model — the one users get on first launch (Hilfer in Phase 4).
    public func starterModel() -> BotModel? {
        models.first { $0.isStarter }
    }
}
