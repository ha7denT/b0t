import FoundationModels
import XCTest

@testable import b0tBrain
@testable import b0tCore

final class ContextAssemblerTests: XCTestCase {
    func test_conversation_includesIdentityCoreAndPrinciples() async throws {
        let bot = try await loadCanonicalBot()
        let assembler = ContextAssembler(bot: bot, store: BotStore())
        let context = try await assembler.assemble(mode: .conversation(userPrompt: "hi"))

        XCTAssertFalse(context.systemInstructions.isEmpty)
        XCTAssertTrue(
            context.systemInstructions.contains("b0t-fixture"),
            "expected b0t_name from identity/core.md frontmatter in instructions"
        )
        XCTAssertTrue(context.loadedFiles.contains("identity/core.md"))
        XCTAssertTrue(context.loadedFiles.contains("identity/principles.md"))
        XCTAssertTrue(context.loadedFiles.contains("memory/core.md"))
    }

    func test_conversation_userPromptCarriesUserMessage() async throws {
        let bot = try await loadCanonicalBot()
        let assembler = ContextAssembler(bot: bot, store: BotStore())
        let context = try await assembler.assemble(mode: .conversation(userPrompt: "remember the meeting"))

        XCTAssertTrue(context.userPrompt.contains("remember the meeting"))
    }

    func test_conversation_recordsBudgetBreakdown() async throws {
        let bot = try await loadCanonicalBot()
        let assembler = ContextAssembler(bot: bot, store: BotStore())
        let context = try await assembler.assemble(mode: .conversation(userPrompt: "hi"))

        XCTAssertGreaterThan(context.budget.estimated, 0)
        XCTAssertEqual(context.budget.limit, 3500)
        XCTAssertEqual(
            context.budget.breakdown.values.reduce(0, +),
            context.budget.estimated,
            "breakdown should sum to estimated"
        )
        XCTAssertNotNil(context.budget.breakdown["identity"])
        XCTAssertNotNil(context.budget.breakdown["memory"])
        XCTAssertNotNil(context.budget.breakdown["userPrompt"])
    }

    func test_heartbeat_includesIdentityAndMemoryAndTriggerContext() async throws {
        let bot = try await loadCanonicalBot()
        let assembler = ContextAssembler(bot: bot, store: BotStore())
        let context = try await assembler.assemble(
            mode: .heartbeat(trigger: .scheduled, missedGap: nil)
        )

        XCTAssertTrue(context.systemInstructions.contains("b0t-fixture"))
        XCTAssertTrue(context.loadedFiles.contains("identity/core.md"))
        XCTAssertTrue(context.loadedFiles.contains("identity/principles.md"))
        XCTAssertTrue(context.loadedFiles.contains("memory/core.md"))
        XCTAssertTrue(
            context.userPrompt.contains("scheduled"),
            "heartbeat prompt should render the trigger kind"
        )
    }

    func test_heartbeat_manualTriggerRendersDifferently() async throws {
        let bot = try await loadCanonicalBot()
        let assembler = ContextAssembler(bot: bot, store: BotStore())
        let context = try await assembler.assemble(
            mode: .heartbeat(trigger: .manual, missedGap: nil)
        )

        XCTAssertTrue(context.userPrompt.contains("manual"))
    }

    func test_heartbeat_includesActionsMdProse() async throws {
        let bot = try await loadCanonicalBot()
        let assembler = ContextAssembler(bot: bot, store: BotStore())
        let context = try await assembler.assemble(
            mode: .heartbeat(trigger: .scheduled, missedGap: nil)
        )

        XCTAssertTrue(
            context.systemInstructions.contains("note the time and update mood"),
            "actions.md prose should be in the heartbeat prompt"
        )
        XCTAssertTrue(context.loadedFiles.contains("heartbeat/actions.md"))
    }

    func test_conversation_includesTimeAwarenessTool() async throws {
        let bot = try await loadCanonicalBot()
        let assembler = ContextAssembler(bot: bot, store: BotStore())
        let context = try await assembler.assemble(mode: .conversation(userPrompt: "hi"))

        XCTAssertEqual(context.tools.count, 1)
        XCTAssertTrue(context.tools.first is TimeAwarenessTool)
    }

    func test_heartbeat_includesTimeAwarenessTool() async throws {
        let bot = try await loadCanonicalBot()
        let assembler = ContextAssembler(bot: bot, store: BotStore())
        let context = try await assembler.assemble(
            mode: .heartbeat(trigger: .scheduled, missedGap: nil)
        )

        XCTAssertEqual(context.tools.count, 1)
        XCTAssertTrue(context.tools.first is TimeAwarenessTool)
    }

    func test_fallback_level1_trimsContent() async throws {
        let bot = try await loadFixtureBot(named: "full-budget-bot")
        let assembler = ContextAssembler(bot: bot, store: BotStore())
        let context = try await assembler.assemble(
            mode: .conversation(userPrompt: "hello"),
            fallbackLevel: 1
        )
        XCTAssertTrue(
            context.budget.didFallBackToDigest,
            "level-1 fallback should mark didFallBackToDigest"
        )
    }

    func test_fallback_level3_surfacesOverflow() async throws {
        let bot = try await loadFixtureBot(named: "full-budget-bot")
        let assembler = ContextAssembler(bot: bot, store: BotStore())
        let context = try await assembler.assemble(
            mode: .conversation(userPrompt: "hello"),
            fallbackLevel: 3
        )
        XCTAssertTrue(context.budget.didFallBackToDigest)
        // Level 3 should produce a self-aware "context overflowed" prompt rather than the user's prompt.
        XCTAssertFalse(context.userPrompt.contains("hello"))
    }

    private func loadCanonicalBot() async throws -> Bot {
        let fixturesURL = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/canonical-bot")
        let store = BotStore()
        return try await store.load(at: fixturesURL)
    }

    private func loadFixtureBot(named name: String) async throws -> Bot {
        let fixturesURL = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/\(name)")
        let store = BotStore()
        return try await store.load(at: fixturesURL)
    }
}
