import FoundationModels
import XCTest

@testable import b0tBrain
@testable import b0tCore

final class ConversationManagerTests: XCTestCase {
    func test_respond_buildsAssembledContextFromBot_passesToClient() async throws {
        let bot = try await loadCanonicalBot()
        let store = BotStore()
        let stub = StubLanguageModelClient { context, _ in
            // Real context now: instructions reference the bot, prompt carries the user message.
            XCTAssertTrue(
                context.systemInstructions.contains("b0t-fixture"),
                "expected b0t_name from identity/core.md frontmatter in instructions")
            XCTAssertTrue(context.userPrompt.contains("hello"))
            XCTAssertGreaterThan(context.budget.estimated, 0)
            return ConversationResponse(text: "echo: hello")
        }
        let manager = ConversationManager(bot: bot, store: store, client: stub)

        let response = try await manager.respond(to: "hello")

        XCTAssertEqual(response.text, "echo: hello")
    }

    private func loadCanonicalBot() async throws -> Bot {
        let fixturesURL = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/canonical-bot")
        let store = BotStore()
        return try await store.load(at: fixturesURL)
    }
}
