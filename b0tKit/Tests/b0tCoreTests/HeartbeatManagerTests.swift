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

    func test_tick_duringQuietHours_suppressesAndJournals() async throws {
        let bot = try await loadFixtureBotInTempCopy(named: "quiet-hours-bot")
        let store = BotStore()

        // Stub raises if called — quiet-hours should suppress before the model is invoked.
        let stub = StubLanguageModelClient { _, _ in
            XCTFail("client must not be called during quiet hours")
            return TickDecision(observed: "", considered: [], decided: "", why: "", acted: "")
        }
        let date = ISO8601DateFormatter().date(from: "2026-05-01T12:00:00Z")!
        let manager = HeartbeatManager(
            bot: bot, store: store, client: stub, clock: FixedClock(date)
        )

        let result = try await manager.tick(trigger: .scheduled)

        switch result {
        case .suppressed(let reason):
            XCTAssertEqual(reason, .quietHours)
        default:
            XCTFail("expected .suppressed(.quietHours), got \(result)")
        }

        // Journal should contain a suppression entry.
        let journalURL = bot.journal.directoryURL.appendingPathComponent("2026-05-01.md")
        let content = try String(contentsOf: journalURL, encoding: .utf8)
        XCTAssertTrue(content.contains("## 12:00 \u{2014} heartbeat 1 \u{2014} suppressed"))
        XCTAssertTrue(content.contains("**reason:** quiet hours"))
    }

    func test_tick_afterLargeGap_prependsMissedBeatNoteToPrompt() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()

        // Pre-populate today's journal with one entry from 2 hours ago — way
        // longer than the canonical 30-minute BPM × 1.5 threshold.
        let journalDir = bot.journal.directoryURL
        try FileManager.default.createDirectory(at: journalDir, withIntermediateDirectories: true)
        let twoHoursAgo = "12:30"
        let journalContent = """
            ---
            date: 2026-05-01
            ---

            ## \(twoHoursAgo) \u{2014} heartbeat 1

            **observed:** stale
            **considered:** pass
            **decided:** pass
            **why:** stale
            **acted:** noted silently
            **state_delta:** none

            """
        try Data(journalContent.utf8).write(
            to: journalDir.appendingPathComponent("2026-05-01.md"),
            options: [.atomic]
        )

        final class CapturedPrompt: @unchecked Sendable {
            var value: String?
        }
        let captured = CapturedPrompt()

        let stub = StubLanguageModelClient { context, _ in
            captured.value = context.userPrompt
            return TickDecision(
                observed: "after a gap",
                considered: ["pass"],
                decided: "pass",
                why: "caught up",
                acted: "noted silently"
            )
        }
        let now = ISO8601DateFormatter().date(from: "2026-05-01T14:30:00Z")!
        let manager = HeartbeatManager(
            bot: bot, store: store, client: stub, clock: FixedClock(now)
        )

        _ = try await manager.tick(trigger: .scheduled)

        XCTAssertNotNil(captured.value)
        XCTAssertTrue(
            captured.value!.contains("longer gap than usual"),
            "prompt should include missed-beat note; got: \(captured.value ?? "")")
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

    private func loadFixtureBotInTempCopy(named name: String) async throws -> Bot {
        let fixture = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/\(name)")
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: fixture, to: temp)
        addTeardownBlock { try? FileManager.default.removeItem(at: temp) }
        let store = BotStore()
        return try await store.load(at: temp)
    }
}
