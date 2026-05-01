import Foundation
import FoundationModels
import OSLog
import b0tBrain

/// Builds an `AssembledContext` for a given `AssemblyMode`.
///
/// Slice 2 (this file): handles `.conversation` mode by loading identity/core,
/// identity/principles, and memory/core from the bot. The user prompt is
/// rendered into `userPrompt` verbatim.
///
/// Slice 5 (Task 19) extends this to handle `.heartbeat` mode by additionally
/// including the full body of `actions.md` and any trigger/missed-gap context.
///
/// Slice 7 (Task 28) extends `.heartbeat` to prepend a missed-beat note when
/// `missedGap` exceeds `bpmInterval × 1.5`.
///
/// Slice 10 (Task 37) implements the graduated overflow fallback for
/// `.fallback(level:base:)` mode.
///
/// See spec §7.1, §7.2, §7.4.
public struct ContextAssembler: Sendable {
    private let bot: Bot
    private let store: BotStore

    private static let logger = Logger(
        subsystem: "com.toppeross.b0t.b0tCore", category: "ContextAssembler"
    )
    private static let limit = 3500

    public init(bot: Bot, store: BotStore) {
        self.bot = bot
        self.store = store
    }

    public func assemble(mode: AssemblyMode) async throws -> AssembledContext {
        switch mode {
        case .conversation(let userPrompt):
            return try await assembleConversation(userPrompt: userPrompt)
        case .heartbeat:
            // Slice 5 implements this branch.
            fatalError("heartbeat mode not implemented until Slice 5")
        case .fallback:
            // Slice 10 implements this branch.
            fatalError("fallback mode not implemented until Slice 10")
        }
    }

    private func assembleConversation(userPrompt: String) async throws -> AssembledContext {
        let identityCore = try await bot.identity.core
        let identityPrinciples = try await bot.identity.principles
        let memoryCore = try await bot.memory.core

        let identityText = [identityCore.prose, identityPrinciples.prose].joined(separator: "\n\n")
        let memoryText = memoryCore.prose

        let systemInstructions = """
            you are the b0t named '\(bot.rootURL.lastPathComponent)'.

            identity:
            \(identityText)

            what you remember about the user:
            \(memoryText)
            """

        let identityTokens = TokenEstimator.estimate(identityText)
        let memoryTokens = TokenEstimator.estimate(memoryText)
        let promptTokens = TokenEstimator.estimate(userPrompt)
        let total = identityTokens + memoryTokens + promptTokens

        let breakdown = [
            "identity": identityTokens,
            "memory": memoryTokens,
            "userPrompt": promptTokens,
        ]

        let budget = TokenBudget(
            estimated: total,
            limit: Self.limit,
            breakdown: breakdown,
            didFallBackToDigest: false
        )

        Self.logger.debug(
            "assembled conversation prompt — total: \(total), breakdown: \(breakdown)"
        )

        return AssembledContext(
            systemInstructions: systemInstructions,
            userPrompt: userPrompt,
            tools: [],
            budget: budget,
            loadedFiles: [
                "identity/core.md",
                "identity/principles.md",
                "memory/core.md",
            ]
        )
    }
}
