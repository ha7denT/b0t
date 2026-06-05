import Combine
import XCTest
import b0tBrain

@testable import b0tCore

final class ConversationUsageTests: XCTestCase {
    func test_respond_emitsUsage_withInputFromBudgetAndOutputFromResponse() async throws {
        // Load the canonical-bot fixture (respond() assembles → needs real files).
        let fixturesURL = Bundle.module.resourceURL!.appendingPathComponent("Fixtures/canonical-bot")
        let store = BotStore()
        let bot = try await store.load(at: fixturesURL)
        let stub = StubLanguageModelClient { _, outputType in
            ConversationResponse(text: "hello there friend")
        }
        let manager = ConversationManager(
            bot: bot, store: store, client: stub, modelIdProvider: { "qwen3-1.7b" })

        var received: GenerationUsage?
        let cancellable = manager.usageEvents.sink { received = $0 }
        defer { cancellable.cancel() }

        _ = try await manager.respond(to: "hi")

        let usage = try XCTUnwrap(received)
        XCTAssertEqual(usage.modelId, "qwen3-1.7b")
        XCTAssertGreaterThan(usage.tokensIn, 0)
        XCTAssertEqual(usage.tokensOut, TokenEstimator.estimate("hello there friend"))
        XCTAssertGreaterThan(usage.limit, 0)
    }
}
