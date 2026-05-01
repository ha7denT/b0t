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
        XCTAssertTrue(content.hasPrefix("---\n"))
        XCTAssertTrue(content.contains("date: 2026-05-01\n"))
        XCTAssertTrue(content.contains("---\n"))
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
