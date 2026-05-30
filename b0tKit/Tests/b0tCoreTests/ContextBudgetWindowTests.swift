import XCTest

@testable import b0tBrain
@testable import b0tCore

final class ContextBudgetWindowTests: XCTestCase {
    func test_limitDerivesFromContextWindow() async throws {
        let fixturesURL = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/canonical-bot")
        let store = BotStore()
        let bot = try await store.load(at: fixturesURL)
        let assembler = ContextAssembler(bot: bot, store: BotStore(), contextWindow: 2048)
        let ctx = try await assembler.assemble(mode: .conversation(userPrompt: "hi"))
        XCTAssertEqual(ctx.budget.limit, 2048 - ContextAssembler.responseReserve)
    }
}
