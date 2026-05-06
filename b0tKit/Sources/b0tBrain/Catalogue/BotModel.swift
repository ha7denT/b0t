import Foundation

/// A specific b0t Model under a Manufacturer (e.g. Hilfer under Wundercog).
/// Carries the three baked Parts, palette, decals, and default
/// modules/tools/personality the bot ships with on first provision.
public struct BotModel: Codable, Sendable, Equatable {
    public let id: String
    public let manufacturer: String
    public let tier: Int
    public let isStarter: Bool
    public let parts: Parts
    public let palette: String
    public let decals: [String]
    public let defaultPersonalityDir: String
    public let defaultModules: [String]
    public let defaultTools: [String]
    public let heartbeatUnlockThreshold: Int?

    public struct Parts: Codable, Sendable, Equatable {
        public let skull: String
        public let eyes: String
        public let jaw: String
    }

    enum CodingKeys: String, CodingKey {
        case id, manufacturer, tier, parts, palette, decals
        case isStarter = "is_starter"
        case defaultPersonalityDir = "default_personality_dir"
        case defaultModules = "default_modules"
        case defaultTools = "default_tools"
        case heartbeatUnlockThreshold = "heartbeat_unlock_threshold"
    }
}
