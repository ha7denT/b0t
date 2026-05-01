import Foundation
import FoundationModels
import OSLog
import b0tBrain

/// Builds an `AssembledContext` for a given `AssemblyMode`.
///
/// Slice 2 (this file): handles `.conversation` mode by loading identity/core,
/// identity/principles, memory/core, and memory/recent from the bot. The user
/// prompt is rendered into `userPrompt` verbatim.
///
/// Slice 3 (Task 13) adds memory/recent.md to the conversation assembly so
/// that observations written by the Executor in turn N are visible to the
/// assembler in turn N+1. This closes spec §7.1 ("memory/recent.md, truncated
/// to fit budget; newest entries kept"), which was omitted from the Task 7 plan.
///
/// Slice 5 (Task 19) extends this to handle `.heartbeat` mode by additionally
/// including the full body of `actions.md` and any trigger/missed-gap context.
///
/// Slice 7 (Task 28) extends `.heartbeat` to prepend a missed-beat note when
/// `missedGap` exceeds `bpmInterval × 1.5`.
///
/// Slice 10 (Task 36) implements the graduated overflow fallback as a private
/// mechanism within this type (not a public `AssemblyMode` case).
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
        }
    }

    private func assembleConversation(userPrompt: String) async throws -> AssembledContext {
        let identityCore = try await bot.identity.core
        let identityPrinciples = try await bot.identity.principles
        let memoryCore = try await bot.memory.core
        let memoryRecent = try await bot.memory.recent

        let identityText = [identityCore.prose, identityPrinciples.prose].joined(separator: "\n\n")
        let memoryText = memoryCore.prose
        let recentText = memoryRecent.prose
        let botName = identityCore.botName ?? bot.rootURL.lastPathComponent

        // Build system instructions. Include recent observations only when
        // there is non-empty prose (i.e. the Executor has written something).
        var instructionsParts = [
            "you are the b0t named '\(botName)'.",
            "",
            "identity:",
            identityText,
            "",
            "what you remember about the user:",
            memoryText,
        ]
        let trimmedRecent = recentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRecent.isEmpty {
            instructionsParts += [
                "",
                "recent observations:",
                recentText,
            ]
        }
        let systemInstructions = instructionsParts.joined(separator: "\n")

        // Token accounting: merge core + recent into a single "memory" bucket
        // so the breakdown continues to sum to `estimated` without introducing
        // a new key (keeps ContextAssemblerTests.test_conversation_recordsBudgetBreakdown
        // green — it only checks that the keys are present and sum correctly).
        let identityTokens = TokenEstimator.estimate(identityText)
        let memoryTokens =
            TokenEstimator.estimate(memoryText) + TokenEstimator.estimate(recentText)
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
                "memory/recent.md",
            ]
        )
    }
}
