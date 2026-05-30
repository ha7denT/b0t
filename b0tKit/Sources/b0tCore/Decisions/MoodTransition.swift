import Foundation
import FoundationModels

/// A record of a mood change.
///
/// Defined in Phase 2 (spec §6) but not exercised end-to-end. Phase 4's
/// face rig is the first consumer — it will read transitions to drive
/// face state changes via SKAction sequences.
@Generable
public struct MoodTransition: Sendable, Equatable, Codable {
    @Guide(description: "The mood you were in.")
    public let from: MoodTag

    @Guide(description: "The mood you're transitioning to.")
    public let to: MoodTag

    @Guide(description: "Why the mood changed — one short sentence.")
    public let why: String

    public init(from: MoodTag, to: MoodTag, why: String) {
        self.from = from
        self.to = to
        self.why = why
    }
}
