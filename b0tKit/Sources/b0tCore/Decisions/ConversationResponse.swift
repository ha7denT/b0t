import Foundation
import FoundationModels

/// The model's output for a user conversation turn.
///
/// Phase 2 slice 1 ships only the `text` field; slice 3 adds `mood` and
/// `memoryObservations`. The `@Generable` macro tells Foundation Models
/// how to produce a typed value of this shape from the model.
@Generable
public struct ConversationResponse: Sendable, Equatable {
    @Guide(description: "The reply the b0t says to the user.")
    public let text: String

    public init(text: String) {
        self.text = text
    }
}
