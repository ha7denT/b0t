import Foundation
import FoundationModels

/// The model's output for a user conversation turn.
///
/// `mood` is optional — the model only sets it when the mood meaningfully
/// changes. `memoryObservations` may be empty when the turn produces no
/// new things to remember.
///
/// Per spec §3 / §5.5, this type does NOT carry a `tool_calls` field —
/// Apple's `LanguageModelSession` orchestrates tool dispatch automatically
/// via the session's `tools:` parameter.
@Generable
public struct ConversationResponse: Sendable, Equatable {
    @Guide(description: "The reply the b0t says to the user. Sentence case, warm, specific.")
    public let text: String

    @Guide(description: "The b0t's current mood, or nil if no meaningful change.")
    public let mood: MoodTag?

    @Guide(description: "Things to remember from this turn. Empty if nothing notable.")
    public let memoryObservations: [MemoryObservation]

    public init(text: String, mood: MoodTag? = nil, memoryObservations: [MemoryObservation] = []) {
        self.text = text
        self.mood = mood
        self.memoryObservations = memoryObservations
    }
}
