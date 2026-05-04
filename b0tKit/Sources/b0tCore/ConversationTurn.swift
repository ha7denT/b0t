import Foundation
import b0tBrain

/// The full result of a single user-turn flow: the typed model response
/// plus the tool-call records observed during the turn.
///
/// Returned by `ConversationManager.respond(to:)`. `DebugBrainView` (and
/// later Phase-4 surfaces) renders `toolCalls` inline between the user
/// prompt and the assistant reply.
///
/// `ConversationResponse` is `@Generable` (model-produced); `toolCalls` is
/// observed-by-runtime. Keeping them as separate fields preserves that
/// ontological distinction.
public struct ConversationTurn: Sendable {
    public let response: ConversationResponse
    public let toolCalls: [ToolCallRecord]

    public init(response: ConversationResponse, toolCalls: [ToolCallRecord]) {
        self.response = response
        self.toolCalls = toolCalls
    }
}
