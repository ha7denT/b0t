import Combine
import XCTest
import b0tBrain

@testable import b0tCore

final class HeartbeatUsageTests: XCTestCase {

    // Local fixed clock — mirrors the one in HeartbeatManagerTests to avoid
    // quiet-hours suppression from the default SystemClock.
    private final class FixedClock: Clock, @unchecked Sendable {
        let date: Date
        init(_ date: Date) { self.date = date }
        func now() -> Date { date }
    }

    func test_tick_emitsUsage_onDecidedBeat() async throws {
        // Copy the fixture to a temp dir — tick() writes a journal entry so
        // the shared bundle copy must not be mutated.
        let source = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/canonical-bot")
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: source, to: temp)
        addTeardownBlock { try? FileManager.default.removeItem(at: temp) }
        let store = BotStore()
        let bot = try await store.load(at: temp)

        let stub = StubLanguageModelClient { _, _ in
            TickDecision(
                observed: "afternoon",
                considered: ["pass"],
                decided: "pass",
                why: "nothing urgent",
                acted: "noted silently"
            )
        }

        // 14:32 UTC is well outside the canonical-bot's quiet hours (22:00–06:30),
        // so the tick will reach the model and return .decided.
        let clock = FixedClock(ISO8601DateFormatter().date(from: "2026-05-01T14:32:00Z")!)

        let manager = HeartbeatManager(
            bot: bot, store: store, client: stub,
            clock: clock,
            modelIdProvider: { "llama-3.2-1b" })

        var received: GenerationUsage?
        let cancellable = manager.usageEvents.sink { received = $0 }
        defer { cancellable.cancel() }

        // .manual bypasses no extra logic — the quiet-hours guard is time-based,
        // and FixedClock gives us 14:32 UTC which is outside quiet hours.
        let result = try await manager.tick(trigger: .manual)

        // Confirm the beat was decided (not suppressed or errored).
        if case .decided(let d, _, _) = result {
            XCTAssertEqual(d.decided, "pass")
        } else {
            XCTFail("expected .decided, got \(result)")
        }

        let usage = try XCTUnwrap(received)
        XCTAssertEqual(usage.modelId, "llama-3.2-1b")
        XCTAssertGreaterThan(usage.tokensIn, 0)
        XCTAssertEqual(usage.tokensOut, TokenEstimator.estimate("noted silently"))
        XCTAssertGreaterThan(usage.limit, 0)
    }
}
