import Foundation
import FoundationModels

/// The b0t's expressed mood. Each pixel-art face must support all 8 states
/// per PRD §5.4 (b0tFace, Phase 4). Listed in `MoodTag` so models and the
/// face rig share a vocabulary.
@Generable
public enum MoodTag: String, Codable, Sendable, Equatable, CaseIterable {
    case idle
    case speaking
    case thinking
    case surprised
    case sleepy
    case attentive
    case worried
    case delighted
}
