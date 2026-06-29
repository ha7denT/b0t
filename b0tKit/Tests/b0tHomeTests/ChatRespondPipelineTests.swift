import Combine
import XCTest

import b0tBrain

@testable import b0tCore
@testable import b0tHome

/// Drives the production chat wiring end-to-end on the host: a real
/// `ConversationManager` (an `actor`) publishing `usageEvents`/`toolCallEvents`
/// into the real `@MainActor` `UsageListener`/`ToolInvocationListener`. Because
/// the manager sends from its actor executor (off-main), the listeners' sinks
/// were main-actor-isolated and SIGTRAPed off-main — the on-device "freeze"/kill
/// (2026-06-29). With `.receive(on: .main)` they deliver on the main run loop and
/// this turn completes. Guards against regressing that crash.
@MainActor
final class ChatRespondPipelineTests: XCTestCase {
    func test_respond_completesWithListenersWired() async throws {
        // Copy the shipped default-bot into a temp dir so assemble() can read
        // real identity/memory files and respond()'s journal write is isolated.
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // b0tHomeTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // b0tKit
            .deletingLastPathComponent()  // repo root
        let source = repoRoot.appendingPathComponent("default-bot")
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: source, to: dir)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }

        let store = BotStore()
        let bot = try await store.load(at: dir)
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)

        let stub = StubLanguageModelClient { _, outputType in
            if outputType == ConversationResponse.self {
                return ConversationResponse(text: "(stub) heard you")
            }
            preconditionFailure("unexpected \(outputType)")
        }

        let manager = ConversationManager(
            bot: bot,
            store: store,
            client: stub,
            modelIdProvider: { "test-model" }
        )
        state.manager = manager

        // Wire the SAME listeners HomeView wires in production.
        let usage = UsageListener(state: state, source: manager.usageEvents.eraseToAnyPublisher())
        usage.start()
        let tools = ToolInvocationListener(
            state: state, source: manager.toolCallEvents.eraseToAnyPublisher())
        tools.start()
        defer {
            usage.stop()
            tools.stop()
        }

        // If respond() hangs (deadlock), this await never returns and the test
        // times out — reproducing the freeze deterministically.
        let turn = try await manager.respond(to: "hello")
        XCTAssertEqual(turn.response.text, "(stub) heard you")

        // Let the MainActor hop run, then confirm the usage gauge updated.
        var sawUsage = false
        for _ in 0..<200 {
            if state.latestUsage != nil {
                sawUsage = true
                break
            }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertTrue(sawUsage, "usage event should have reached the listener")
    }
}
