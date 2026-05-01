import Foundation
import FoundationModels
import b0tBrain

/// Orchestrates a single user-turn flow: prompt → context → model → response.
///
/// Slice 1 introduced the actor and the prompt-passthrough placeholder.
/// Slice 2 (Task 8) wraps `ContextAssembler.assemble(.conversation(...))`.
/// Slice 3 (this commit) applies `Executor` to memory observations.
/// Slice 4 (Task 17) will append a journal entry per turn.
///
/// The manager is an `actor` so concurrent UI inputs are serialised — the
/// caller doesn't have to coordinate. State that survives a single call
/// (turn-number counter for journaling) is held on the actor.
public actor ConversationManager {
    private let bot: Bot
    private let store: BotStore
    private let client: any LanguageModelClient
    private let clock: any Clock
    private let assembler: ContextAssembler
    private let executor: Executor

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
        self.assembler = ContextAssembler(bot: bot, store: store)
        self.executor = Executor(bot: bot, store: store)
    }

    public func respond(to userPrompt: String) async throws -> ConversationResponse {
        let context = try await assembler.assemble(
            mode: .conversation(userPrompt: userPrompt)
        )
        let response = try await client.generate(
            context: context,
            generating: ConversationResponse.self
        )
        _ = try await executor.apply(response)
        return response
    }
}
