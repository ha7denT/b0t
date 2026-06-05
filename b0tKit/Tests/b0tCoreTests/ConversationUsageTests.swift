import Combine
import XCTest
import b0tBrain

@testable import b0tCore

final class ConversationUsageTests: XCTestCase {
    func test_respond_emitsUsage_withInputFromBudgetAndOutputFromResponse() async throws {
        // Copy the fixture to a temp dir so respond()'s journal write doesn't
        // pollute the shared bundle copy and break other tests.
        let source = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/canonical-bot")
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: source, to: temp)
        addTeardownBlock { try? FileManager.default.removeItem(at: temp) }
        let store = BotStore()
        let bot = try await store.load(at: temp)
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
