import Foundation
import FoundationModels
import b0tBrain

/// Orchestrates a single user-turn flow: prompt → context → model → response.
///
/// Slice 1 (this file): prompt is passed through as-is to the client.
/// Slice 2 (Task 9): wraps `ContextAssembler.assemble(.conversation(...))`.
/// Slice 3 (Task 14): applies `Executor` to memory observations.
/// Slice 4 (Task 17): appends a journal entry per turn.
///
/// The manager is an `actor` so concurrent UI inputs are serialised — the
/// caller doesn't have to coordinate. State that survives a single call
/// (turn-number counter for journaling) is held on the actor.
public actor ConversationManager {
    private let bot: Bot
    private let store: BotStore
    private let client: any LanguageModelClient
    private let clock: any Clock

    public init(
        bot: Bot,
        store: BotStore,
        client: any LanguageModelClient,
        clock: any Clock = SystemClock()
    ) {
        self.bot = bot
        self.store = store
        self.client = client
        self.clock = clock
    }

    public func respond(to userPrompt: String) async throws -> ConversationResponse {
        let context = AssembledContext(userPrompt: userPrompt)
        return try await client.generate(
            context: context,
            generating: ConversationResponse.self
        )
    }
}
