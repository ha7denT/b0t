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
            why: "afternoon, calendar module enabled, deadline today",
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
            **why:** afternoon, calendar module enabled, deadline today
            **acted:** noted upcoming meeting silently
            **mood:** attentive
            **organ_used:** calendar
            **state_delta:** memory/recent.md

            """
        XCTAssertEqual(content, expected)
    }

    func test_appendSuppressed_writesByteExactEntry() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()
        let date = ISO8601DateFormatter().date(from: "2026-05-01T23:14:00Z")!
        let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

        try await writer.appendSuppressed(reason: .quietHours, beatNumber: 248)

        let content = try String(contentsOf: writer.journalURL(for: date), encoding: .utf8)
        let expected = """
            ---
            date: 2026-05-01
            ---

            ## 23:14 \u{2014} heartbeat 248 \u{2014} suppressed

            **reason:** quiet hours
            **state_delta:** none

            """
        XCTAssertEqual(content, expected)
    }

    func test_appendError_turn_writesByteExactEntry() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()
        let date = ISO8601DateFormatter().date(from: "2026-05-01T14:33:00Z")!
        let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

        try await writer.appendError(
            error: LanguageModelClientError.modelUnavailable,
            kind: .turn(number: 8)
        )

        let content = try String(contentsOf: writer.journalURL(for: date), encoding: .utf8)
        let expected = """
            ---
            date: 2026-05-01
            ---

            ## 14:33 \u{2014} turn 8 \u{2014} error

            **error:** modelUnavailable
            **state_delta:** none

            """
        XCTAssertEqual(content, expected)
    }

    func test_appendError_heartbeat_writesByteExactEntry() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()
        let date = ISO8601DateFormatter().date(from: "2026-05-01T15:00:00Z")!
        let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

        struct Boom: Error, CustomStringConvertible {
            var description: String { "boom" }
        }
        try await writer.appendError(
            error: Boom(),
            kind: .heartbeat(number: 247)
        )

        let content = try String(contentsOf: writer.journalURL(for: date), encoding: .utf8)
        let expected = """
            ---
            date: 2026-05-01
            ---

            ## 15:00 \u{2014} heartbeat 247 \u{2014} error

            **error:** boom
            **state_delta:** none

            """
        XCTAssertEqual(content, expected)
    }

    func test_appendConversationTurn_rendersToolsCalledSubsection() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()

        let date = ISO8601DateFormatter().date(from: "2026-05-01T12:00:00Z")!
        let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

        let response = ConversationResponse(text: "ok", mood: .thinking, memoryObservations: [])
        let records = [
            ToolCallRecord(
                toolName: "time_awareness",
                argumentsSummary: "(no args)",
                outputSummary: "12:00 UTC, afternoon",
                timestamp: date
            )
        ]
        try await writer.appendConversationTurn(
            prompt: "what time",
            response: response,
            stateDelta: .empty,
            turnNumber: 1,
            toolCalls: records
        )

        let content = try String(contentsOf: writer.journalURL(for: date), encoding: .utf8)
        XCTAssertTrue(content.contains("tools_called"), "expected 'tools_called' in journal output")
        XCTAssertTrue(content.contains("time_awareness"), "expected tool name in journal output")
        XCTAssertTrue(content.contains("(no args)"), "expected args summary in journal output")
        XCTAssertTrue(content.contains("12:00 UTC, afternoon"), "expected output summary in journal output")
    }

    func test_appendConversationTurn_omitsToolsCalledIfEmpty() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()

        let date = ISO8601DateFormatter().date(from: "2026-05-01T09:15:00Z")!
        let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

        let response = ConversationResponse(text: "ok", mood: .thinking, memoryObservations: [])
        try await writer.appendConversationTurn(
            prompt: "hi",
            response: response,
            stateDelta: .empty,
            turnNumber: 1,
            toolCalls: []
        )

        let content = try String(contentsOf: writer.journalURL(for: date), encoding: .utf8)
        XCTAssertFalse(
            content.contains("tools_called"),
            "expected 'tools_called' to be absent for empty toolCalls"
        )
    }

    func testAppendTickRendersToolsCalled() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()

        let date = ISO8601DateFormatter().date(from: "2026-05-01T14:00:00Z")!
        let clock = FixedClock(date)
        let writer = JournalWriter(bot: bot, store: store, clock: clock)

        let decision = TickDecision(
            observed: "afternoon",
            considered: ["pass"],
            decided: "pass",
            why: "nothing urgent",
            acted: "noted silently"
        )
        let records = [
            ToolCallRecord(
                toolName: "time_awareness",
                argumentsSummary: "(no args)",
                outputSummary: "12:00",
                timestamp: date
            )
        ]
        try await writer.appendTick(
            decision: decision,
            stateDelta: StateDelta(writtenFiles: [], wouldNotifyText: nil),
            beatNumber: 1,
            toolCalls: records
        )

        let url = writer.journalURL(for: clock.now())
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("tools_called"), "expected 'tools_called' in tick journal output")
        XCTAssertTrue(content.contains("time_awareness"), "expected tool name in tick journal output")
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
