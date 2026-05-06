import Foundation

/// A Manufacturer in the Phase-4-amendment vocabulary — a brand of b0t Models
/// (Wundercog, Kalv, Hartsyzk Robotyka, Solace, Kernel Collective). Each
/// Manufacturer locks a base prompt template, a palette family, and an
/// identity sensibility.
public struct Manufacturer: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let basePromptTemplate: String
    public let palettes: [String]
    public let identityDescription: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case basePromptTemplate = "base_prompt_template"
        case palettes
        case identityDescription = "identity_description"
    }
}
