import Foundation
import XCTest

@testable import b0tBrain
@testable import b0tCore

final class JournalWriterTests: XCTestCase {
    final class FixedClock: b0tCore.Clock, @unchecked Sendable {
        var date: Date
        init(_ date: Date) { self.date = date }
        func now() -> Date { date }
    }

    func test_journalFileURL_isDayKeyed() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()

        let date = ISO8601DateFormatter().date(from: "2026-05-01T14:32:00Z")!
        let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

        let url = writer.journalURL(for: date)
        XCTAssertTrue(url.lastPathComponent == "2026-05-01.md", "got: \(url.lastPathComponent)")
        XCTAssertTrue(url.path.contains("/journal/"))
    }

    func test_firstAppend_createsFileWithDateFrontmatter() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()

        let date = ISO8601DateFormatter().date(from: "2026-05-01T14:32:00Z")!
        let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

        try await writer.ensureJournalExists(for: date)

        let url = writer.journalURL(for: date)
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(content, "---\ndate: 2026-05-01\n---\n\n")
    }

    func test_secondAppend_doesNotReWriteFrontmatter() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()

        let date = ISO8601DateFormatter().date(from: "2026-05-01T14:32:00Z")!
        let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

        try await writer.ensureJournalExists(for: date)
        let firstContent = try String(
            contentsOf: writer.journalURL(for: date),
            encoding: .utf8
        )
        try await writer.ensureJournalExists(for: date)
        let secondContent = try String(
            contentsOf: writer.journalURL(for: date),
            encoding: .utf8
        )
        XCTAssertEqual(
            firstContent, secondContent,
            "second ensure must be a no-op when file exists")
    }

    func test_appendConversationTurn_writesByteExactOpenClawEntry() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()

        let date = ISO8601DateFormatter().date(from: "2026-05-01T14:32:00Z")!
        let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

        let response = ConversationResponse(
            text: "noted \u{2014} added to your memory",
            mood: .attentive,
            memoryObservations: [
                MemoryObservation(
                    about: "Jamee",
                    what: "vendor call at 4pm",
                    importance: .high
                )
            ]
        )
        let stateDelta = StateDelta(
            writtenFiles: [bot.memory.recentURL]
        )

        try await writer.appendConversationTurn(
            prompt: "remember I have a vendor call at 4",
            response: response,
            stateDelta: stateDelta,
            turnNumber: 7
        )

        let url = writer.journalURL(for: date)
        let content = try String(contentsOf: url, encoding: .utf8)

        let expected = """
            ---
            date: 2026-05-01
            ---

            ## 14:32 \u{2014} turn 7

            **observed:** user said: remember I have a vendor call at 4
            **decided:** noted \u{2014} added to your memory
            **mood:** attentive
            **memory_observations:**
            - (high) Jamee: vendor call at 4pm
            **state_delta:** memory/recent.md

            """
        XCTAssertEqual(content, expected)
    }

    func test_appendConversationTurn_omitsOptionalSectionsWhenEmpty() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()

        let date = ISO8601DateFormatter().date(from: "2026-05-01T09:15:00Z")!
        let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

        try await writer.appendConversationTurn(
            prompt: "hi",
            response: ConversationResponse(text: "hello"),
            stateDelta: .empty,
            turnNumber: 1
        )

        let content = try String(contentsOf: writer.journalURL(for: date), encoding: .utf8)
        let expected = """
            ---
            date: 2026-05-01
            ---

            ## 09:15 \u{2014} turn 1

            **observed:** user said: hi
            **decided:** hello
            **state_delta:** none

            """
        XCTAssertEqual(content, expected)
    }

    func test_appendTick_writesByteExactOpenClawEntry() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()

        let date = ISO8601DateFormatter().date(from: "2026-05-01T14:32:00Z")!
        let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

        let decision = TickDecision(
            observed: "schedule wake; been 2h since last beat",
            considered: ["quiet_check", "glance_calendar", "pass"],
            decided: "glance_calendar",
            why: "afternoon, calendar skill enabled, deadline today",
            acted: "noted upcoming meeting silently",
            mood: .attentive,
            organUsed: "calendar"
        )
        let stateDelta = StateDelta(writtenFiles: [bot.memory.recentURL])

        try await writer.appendTick(
            decision: decision,
            stateDelta: stateDelta,
            beatNumber: 247
        )

        let content = try String(contentsOf: writer.journalURL(for: date), encoding: .utf8)
        let expected = """
            ---
            date: 2026-05-01
            ---

            ## 14:32 \u{2014} heartbeat 247

            **observed:** schedule wake; been 2h since last beat
            **considered:** quiet_check, glance_calendar, pass
            **decided:** glance_calendar
            **why:** afternoon, calendar skill enabled, deadline today
            **acted:** noted upcoming meeting silently
            **mood:** attentive
            **organ_used:** calendar
            **state_delta:** memory/recent.md

            """
        XCTAssertEqual(content, expected)
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
