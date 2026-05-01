import FoundationModels
import XCTest

@testable import b0tBrain
@testable import b0tCore

/// Thread-safe box used by `awaitOnMain` in tests to bridge sync→async.
private final class ResultBox<T>: @unchecked Sendable {
    var value: Result<T, Error>?
}

final class ConversationManagerTests: XCTestCase {
    func test_respond_passesPromptThroughToClient_returnsResponse() async throws {
        // Slice 1 behaviour: the manager is a thin wrapper that builds an
        // AssembledContext from the prompt alone (no markdown reads yet),
        // calls the client, and returns the response.
        let bot = try makeFixtureBot()
        let store = BotStore()
        let stub = StubLanguageModelClient { context, _ in
            XCTAssertEqual(context.userPrompt, "hello")
            return ConversationResponse(text: "echo: hello")
        }
        let manager = ConversationManager(bot: bot, store: store, client: stub)

        let response = try await manager.respond(to: "hello")

        XCTAssertEqual(response.text, "echo: hello")
    }

    private func makeFixtureBot() throws -> Bot {
        let fixturesURL = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/canonical-bot")
        let store = BotStore()
        return try awaitOnMain { try await store.load(at: fixturesURL) }
    }

    private func awaitOnMain<T>(_ work: @escaping @Sendable () async throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox<T>()
        Task {
            do { box.value = .success(try await work()) } catch { box.value = .failure(error) }
            semaphore.signal()
        }
        semaphore.wait()
        return try box.value!.get()
    }
}
