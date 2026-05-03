import Foundation
import FoundationModels
import b0tBrain

/// Orchestrates a single user-turn flow: prompt → context → model → executor → journal → response.
///
/// Slice 1 introduced the actor and the prompt-passthrough placeholder.
/// Slice 2 (Task 8) wraps `ContextAssembler.assemble(.conversation(...))`.
/// Slice 3 (Task 13) applies `Executor` to memory observations.
/// Slice 4 (this commit) appends a journal entry per turn via `JournalWriter`.
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
    private let journalWriter: JournalWriter

    private var nextTurnNumber: Int = 1
    private var didLoadTurnNumber: Bool = false

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
        self.journalWriter = JournalWriter(bot: bot, store: store, clock: clock)
    }

    public func respond(to userPrompt: String) async throws -> ConversationResponse {
        if !didLoadTurnNumber {
            nextTurnNumber = await loadNextTurnNumber()
            didLoadTurnNumber = true
        }
        let turnNumber = nextTurnNumber
        nextTurnNumber += 1

        do {
            let response = try await respondWithFallback(userPrompt: userPrompt, level: 0)
            let delta = try await executor.apply(response)
            try await journalWriter.appendConversationTurn(
                prompt: userPrompt,
                response: response,
                stateDelta: delta,
                turnNumber: turnNumber
            )
            return response
        } catch {
            try? await journalWriter.appendError(error: error, kind: .turn(number: turnNumber))
            throw error
        }
    }

    private func respondWithFallback(userPrompt: String, level: Int) async throws -> ConversationResponse {
        let context = try await assembler.assemble(
            mode: .conversation(userPrompt: userPrompt),
            fallbackLevel: level
        )
        do {
            return try await client.generate(context: context, generating: ConversationResponse.self)
        } catch LanguageModelClientError.exceededContextWindowSize {
            if level >= 3 {
                return ConversationResponse(
                    text: "oh — let me start fresh, I was getting muddled.",
                    mood: .thinking,
                    memoryObservations: []
                )
            }
            return try await respondWithFallback(userPrompt: userPrompt, level: level + 1)
        }
    }

    /// Reads today's journal file and returns the next turn number.
    /// Phase 2 simplification: scan for "— turn N" headers (the em-dash matches
    /// JournalWriter's writer format), return max(N) + 1, or 1 if no journal yet.
    /// MUST stay byte-compatible with JournalWriter's "## HH:MM — turn N" header.
    private func loadNextTurnNumber() async -> Int {
        let url = journalWriter.journalURL(for: clock.now())
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return 1 }
        let pattern = "\u{2014} turn ([0-9]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 1 }
        let range = NSRange(content.startIndex..., in: content)
        var maxN = 0
        regex.enumerateMatches(in: content, range: range) { match, _, _ in
            guard let match,
                let nrange = Range(match.range(at: 1), in: content),
                let n = Int(content[nrange])
            else { return }
            if n > maxN { maxN = n }
        }
        return maxN + 1
    }
}
