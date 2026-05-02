import FoundationModels
import XCTest

@testable import b0tBrain
@testable import b0tCore

final class HeartbeatManagerTests: XCTestCase {
    final class FixedClock: Clock, @unchecked Sendable {
        var date: Date
        init(_ date: Date) { self.date = date }
        func now() -> Date { date }
    }

    func test_tick_manualTrigger_callsClient_returnsDecided() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()
        let stub = StubLanguageModelClient { _, _ in
            TickDecision(
                observed: "afternoon",
                considered: ["pass", "glance_calendar"],
                decided: "pass",
                why: "nothing urgent",
                acted: "noted silently",
                mood: .attentive
            )
        }
        let date = ISO8601DateFormatter().date(from: "2026-05-01T14:32:00Z")!
        let manager = HeartbeatManager(
            bot: bot,
            store: store,
            client: stub,
            clock: FixedClock(date)
        )

        let result = try await manager.tick(trigger: .manual)

        switch result {
        case .decided(let d):
            XCTAssertEqual(d.decided, "pass")
            XCTAssertEqual(d.mood, .attentive)
        case .suppressed, .errored:
            XCTFail("expected .decided, got \(result)")
        }
    }

    func test_tick_writesJournalEntryAndAppliesObservations() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()
        let stub = StubLanguageModelClient { _, _ in
            TickDecision(
                observed: "afternoon",
                considered: ["pass", "store_for_later"],
                decided: "store_for_later",
                why: "user mentioned a deadline",
                acted: "noted silently",
                memoryObservations: [
                    MemoryObservation(about: "deadlines", what: "vendor by friday", importance: .medium)
                ]
            )
        }
        let date = ISO8601DateFormatter().date(from: "2026-05-01T15:00:00Z")!
        let manager = HeartbeatManager(
            bot: bot, store: store, client: stub, clock: FixedClock(date)
        )

        _ = try await manager.tick(trigger: .manual)

        // Journal entry written.
        let journalURL = bot.journal.directoryURL.appendingPathComponent("2026-05-01.md")
        let journalContent = try String(contentsOf: journalURL, encoding: .utf8)
        XCTAssertTrue(journalContent.contains("## 15:00 \u{2014} heartbeat 1"))
        XCTAssertTrue(journalContent.contains("decided:** store_for_later"))

        // Memory observation persisted.
        let recent = try await bot.memory.recent
        XCTAssertTrue(recent.prose.contains("vendor by friday"))
    }

    private func loadCanonicalBotInTempCopy() async throws -> Bot {
        let fixture = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/canonical-bot")
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: fixture, to: temp)
        addTeardownBlock { try? FileManager.default.removeItem(at: temp) }
        let store = BotStore()
        return try await store.load(at: temp)
    }
}
