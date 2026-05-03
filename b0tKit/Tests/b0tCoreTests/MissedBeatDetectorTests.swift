import FoundationModels
import XCTest

@testable import b0tBrain
@testable import b0tCore

final class MissedBeatDetectorTests: XCTestCase {
    func test_gap_returnsNilWhenNoJournalExists() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()
        let detector = MissedBeatDetector(bot: bot, store: store)

        // canonical-bot fixture has no journal/2026-05-01.md by default.
        let now = Date()
        let gap = try await detector.gap(now: now)
        XCTAssertNil(gap)
    }

    func test_gap_returnsCorrectDuration() async throws {
        // Build a temp bot with a journal containing a 4-hour-gap entry.
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try copyFixture("canonical-bot", to: temp)
        addTeardownBlock { try? FileManager.default.removeItem(at: temp) }

        let journalDir = temp.appendingPathComponent("journal")
        try FileManager.default.createDirectory(
            at: journalDir, withIntermediateDirectories: true
        )
        let journalContent = """
            ---
            date: 2026-05-01
            ---

            ## 12:30 \u{2014} heartbeat 3

            **observed:** four-hour gap
            **considered:** pass
            **decided:** pass
            **why:** caught up
            **acted:** noted silently
            **state_delta:** none

            """
        try Data(journalContent.utf8).write(
            to: journalDir.appendingPathComponent("2026-05-01.md"), options: [.atomic]
        )

        let store = BotStore()
        let bot = try await store.load(at: temp)
        let detector = MissedBeatDetector(bot: bot, store: store)

        // 14:00 UTC is 90 minutes after 12:30.
        let now = ISO8601DateFormatter().date(from: "2026-05-01T14:00:00Z")!
        let gap = try await detector.gap(now: now)

        XCTAssertNotNil(gap)
        XCTAssertEqual(gap, .seconds(90 * 60))
    }

    private func loadCanonicalBotInTempCopy() async throws -> Bot {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try copyFixture("canonical-bot", to: temp)
        addTeardownBlock { try? FileManager.default.removeItem(at: temp) }
        let store = BotStore()
        return try await store.load(at: temp)
    }

    private func copyFixture(_ name: String, to destination: URL) throws {
        let fixture = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/\(name)")
        try FileManager.default.copyItem(at: fixture, to: destination)
    }
}
