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
    private let tools: [any Tool]
    private let toolsRequirePermission: Bool
    private let windowProvider: @Sendable () -> Int

    /// Effective budget limit = current window minus the response reserve.
    /// Read per-assembly so a live engine swap (Stage D EngineHost) takes effect.
    var limit: Int { max(0, windowProvider() - Self.responseReserve) }

    private static let logger = Logger(
        subsystem: "com.toppeross.b0t.b0tCore", category: "ContextAssembler"
    )

    /// Tokens reserved for the model's response within the context window.
    ///
    /// Chosen so that the default path (contextWindow: 4096) yields a budget
    /// limit of exactly 3500 — preserving the previously hardcoded constant.
    ///   4096 − 596 = 3500
    public static let responseReserve = 596

    private static let permissionHandlingInstruction = """

        Some of your tools may return a result with `permissionDenied: true`. \
        That means you don't have system access yet. When this happens, mention \
        it to the user in your own voice — keep it brief, suggest they can grant \
        access in iOS Settings if they'd like, and don't pretend the tool worked. \
        If you've been denied access, don't keep trying to call the same tool in a turn.
        """

    public init(
        bot: Bot,
        store: BotStore,
        tools: [any Tool] = [],
        toolsRequirePermission: Bool = false,
        contextWindow: Int = 4096
    ) {
        self.init(
            bot: bot, store: store, tools: tools,
            toolsRequirePermission: toolsRequirePermission,
            contextWindowProvider: { contextWindow })
    }

    public init(
        bot: Bot,
        store: BotStore,
        tools: [any Tool],
        toolsRequirePermission: Bool,
        contextWindowProvider: @escaping @Sendable () -> Int
    ) {
        self.bot = bot
        self.store = store
        self.tools = tools
        self.toolsRequirePermission = toolsRequirePermission
        self.windowProvider = contextWindowProvider
    }

    public func assemble(mode: AssemblyMode) async throws -> AssembledContext {
        switch mode {
        case .conversation(let userPrompt):
            return try await assembleConversation(userPrompt: userPrompt)
        case .heartbeat(let trigger, let missedGap):
            return try await assembleHeartbeat(trigger: trigger, missedGap: missedGap)
        }
    }

    /// Internal: assembles with a graduated fallback level (per spec §7.4).
    /// Public callers use `assemble(mode:)` which is `assemble(mode:fallbackLevel: 0)`.
    /// `ConversationManager.respondWithFallback` calls this directly with incrementing
    /// levels on `.exceededContextWindowSize`.
    ///
    /// - level 0: full context (delegates to `assembleConversation`/`assembleHeartbeat`).
    /// - level 1: drops journal entries from conversation; drops actions.md from heartbeat.
    /// - level 2: drops `memory/recent.md`; trims `memory/core` to a digest.
    /// - level 3: surfaces overflow — minimal context, model is asked to acknowledge
    ///   in the b0t voice.
    func assemble(mode: AssemblyMode, fallbackLevel: Int) async throws -> AssembledContext {
        if fallbackLevel == 0 {
            return try await assemble(mode: mode)
        }
        switch mode {
        case .conversation(let userPrompt):
            return try await assembleConversationFallback(level: fallbackLevel, userPrompt: userPrompt)
        case .heartbeat(let trigger, let missedGap):
            return try await assembleHeartbeatFallback(
                level: fallbackLevel, trigger: trigger, missedGap: missedGap)
        }
    }

    private func assembleConversationFallback(level: Int, userPrompt: String) async throws -> AssembledContext
    {
        let identityCore = try await bot.identity.core
        let identityPrinciples = try await bot.identity.principles

        let botName = identityCore.botName ?? bot.rootURL.lastPathComponent
        let identityText: String
        let memoryText: String
        let loadedFiles: [String]

        switch level {
        case 1:
            // Drop journal/recent entries; keep identity + memory/core.
            let memoryCore = try await bot.memory.core
            identityText = [identityCore.prose, identityPrinciples.prose].joined(separator: "\n\n")
            memoryText = memoryCore.prose
            loadedFiles = ["identity/core.md", "identity/principles.md", "memory/core.md"]
        case 2:
            // Drop memory/recent and memory/core; keep only identity/core summary.
            identityText = identityCore.prose
            memoryText = "(memory trimmed)"
            loadedFiles = ["identity/core.md"]
        default:
            // Level 3+: surface the overflow.
            identityText = "(identity trimmed)"
            memoryText = "(memory trimmed)"
            loadedFiles = ["identity/core.md"]
        }

        let systemInstructions = """
            you are the b0t named '\(botName)'.

            identity:
            \(identityText)

            what you remember about the user:
            \(memoryText)
            """

        let prompt: String
        if level >= 3 {
            prompt =
                "you have lost most of your context. acknowledge this briefly to the user in your voice and ask them to repeat the essential."
        } else {
            prompt = userPrompt
        }

        let identityTokens = TokenEstimator.estimate(identityText)
        let memoryTokens = TokenEstimator.estimate(memoryText)
        let promptTokens = TokenEstimator.estimate(prompt)
        let total = identityTokens + memoryTokens + promptTokens

        let budget = TokenBudget(
            estimated: total,
            limit: self.limit,
            breakdown: [
                "identity": identityTokens,
                "memory": memoryTokens,
                "userPrompt": promptTokens,
            ],
            didFallBackToDigest: true
        )

        Self.logger.debug("assembled fallback (level \(level)) — total: \(total)")

        let finalInstructions =
            toolsRequirePermission
            ? systemInstructions + Self.permissionHandlingInstruction
            : systemInstructions
        return AssembledContext(
            systemInstructions: finalInstructions,
            userPrompt: prompt,
            tools: self.tools,
            toolsRequirePermission: self.toolsRequirePermission,
            budget: budget,
            loadedFiles: loadedFiles
        )
    }

    private func assembleHeartbeatFallback(
        level: Int,
        trigger: TickTrigger,
        missedGap: Duration?
    ) async throws -> AssembledContext {
        let identityCore = try await bot.identity.core
        let botName = identityCore.botName ?? bot.rootURL.lastPathComponent
        let identityText = identityCore.prose

        let systemInstructions = """
            you are the b0t named '\(botName)'.

            identity:
            \(identityText)

            (memory and actions trimmed for budget)
            """

        let prompt: String
        if level >= 3 {
            prompt =
                "your context overflowed. produce a minimal TickDecision with decided: 'pass' and acted: 'noted silently'."
        } else {
            prompt = "you woke from a \(trigger.rawValue) beat. produce a TickDecision."
        }

        let identityTokens = TokenEstimator.estimate(identityText)
        let promptTokens = TokenEstimator.estimate(prompt)
        let total = identityTokens + promptTokens

        let budget = TokenBudget(
            estimated: total,
            limit: self.limit,
            breakdown: ["identity": identityTokens, "userPrompt": promptTokens],
            didFallBackToDigest: true
        )

        Self.logger.debug("assembled heartbeat fallback (level \(level)) — total: \(total)")

        let finalInstructions =
            toolsRequirePermission
            ? systemInstructions + Self.permissionHandlingInstruction
            : systemInstructions
        return AssembledContext(
            systemInstructions: finalInstructions,
            userPrompt: prompt,
            tools: self.tools,
            toolsRequirePermission: self.toolsRequirePermission,
            budget: budget,
            loadedFiles: ["identity/core.md"]
        )
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
            limit: self.limit,
            breakdown: breakdown,
            didFallBackToDigest: false
        )

        Self.logger.debug(
            "assembled conversation prompt — total: \(total), breakdown: \(breakdown)"
        )

        let finalInstructions =
            toolsRequirePermission
            ? systemInstructions + Self.permissionHandlingInstruction
            : systemInstructions
        return AssembledContext(
            systemInstructions: finalInstructions,
            userPrompt: userPrompt,
            tools: self.tools,
            toolsRequirePermission: self.toolsRequirePermission,
            budget: budget,
            loadedFiles: [
                "identity/core.md",
                "identity/principles.md",
                "memory/core.md",
                "memory/recent.md",
            ]
        )
    }

    private func assembleHeartbeat(
        trigger: TickTrigger,
        missedGap: Duration?
    ) async throws -> AssembledContext {
        let identityCore = try await bot.identity.core
        let identityPrinciples = try await bot.identity.principles
        let memoryCore = try await bot.memory.core
        let actions = try await bot.heartbeat.actions

        let botName = identityCore.botName ?? bot.rootURL.lastPathComponent
        let identityText = [identityCore.prose, identityPrinciples.prose].joined(separator: "\n\n")
        let memoryText = memoryCore.prose
        let actionsText = actions.prose

        let systemInstructions = """
            you are the b0t named '\(botName)'.

            identity:
            \(identityText)

            what you remember about the user:
            \(memoryText)

            what to do at each beat (your action playbook):
            \(actionsText)
            """

        let triggerLine = "you woke from a \(trigger.rawValue) beat."
        let userPrompt: String
        if let missedGap {
            let minutes = Int(missedGap.timeInterval / 60)
            userPrompt = """
                \(triggerLine)
                you have not woken in about \(minutes) minutes — that's a longer gap than usual. iOS may have skipped beats. you can mention this if it feels natural.

                decide what to do at this beat. produce a TickDecision following the OpenClaw fields.
                """
        } else {
            userPrompt = """
                \(triggerLine)

                decide what to do at this beat. produce a TickDecision following the OpenClaw fields.
                """
        }

        let identityTokens = TokenEstimator.estimate(identityText)
        let memoryTokens = TokenEstimator.estimate(memoryText)
        let actionsTokens = TokenEstimator.estimate(actionsText)
        let promptTokens = TokenEstimator.estimate(userPrompt)
        let total = identityTokens + memoryTokens + actionsTokens + promptTokens

        let breakdown = [
            "identity": identityTokens,
            "memory": memoryTokens,
            "actions": actionsTokens,
            "userPrompt": promptTokens,
        ]
        let budget = TokenBudget(
            estimated: total,
            limit: self.limit,
            breakdown: breakdown,
            didFallBackToDigest: false
        )

        Self.logger.debug("assembled heartbeat prompt — total: \(total), trigger: \(trigger.rawValue)")

        let finalInstructions =
            toolsRequirePermission
            ? systemInstructions + Self.permissionHandlingInstruction
            : systemInstructions
        return AssembledContext(
            systemInstructions: finalInstructions,
            userPrompt: userPrompt,
            tools: self.tools,
            toolsRequirePermission: self.toolsRequirePermission,
            budget: budget,
            loadedFiles: [
                "identity/core.md",
                "identity/principles.md",
                "memory/core.md",
                "heartbeat/actions.md",
            ]
        )
    }
}

extension Duration {
    /// Converts this Duration into seconds as a TimeInterval.
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return Double(seconds) + Double(attoseconds) / 1e18
    }
}
