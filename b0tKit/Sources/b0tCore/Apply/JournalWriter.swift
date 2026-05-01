import Foundation
import OSLog
import b0tBrain

/// Appends OpenClaw-format entries to `journal/YYYY-MM-DD.md`.
///
/// Slice 4 (this file): scaffolding + appendConversationTurn (Task 15).
/// Slice 5 (Task 21): appendTick.
/// Slice 6 (Task 23): appendSuppressed.
/// Slice 10 (Task 38): appendError.
///
/// Per spec §7.3, the journal file's day-keyed name comes from the writer's
/// clock (in the bot's time zone — UTC for now; Phase 4 may revisit). The
/// first append of a day creates the file with `---\ndate: YYYY-MM-DD\n---\n`
/// frontmatter. Subsequent appends to the same day's file just add an entry
/// after the existing content, separated by a blank line.
public struct JournalWriter: Sendable {
    private let bot: Bot
    private let store: BotStore
    private let clock: any Clock

    private static let logger = Logger(
        subsystem: "com.toppeross.b0t.b0tCore",
        category: "JournalWriter"
    )

    public init(bot: Bot, store: BotStore, clock: any Clock) {
        self.bot = bot
        self.store = store
        self.clock = clock
    }

    /// The on-disk URL for the journal file representing `date`'s day.
    public func journalURL(for date: Date) -> URL {
        let dayString = Self.dayString(for: date)
        return bot.journal.directoryURL
            .appendingPathComponent("\(dayString).md")
    }

    /// Idempotent: creates `journal/YYYY-MM-DD.md` with date frontmatter if it
    /// does not yet exist. No-op otherwise.
    public func ensureJournalExists(for date: Date) async throws {
        let url = journalURL(for: date)
        if FileManager.default.fileExists(atPath: url.path) { return }

        try FileManager.default.createDirectory(
            at: bot.journal.directoryURL,
            withIntermediateDirectories: true
        )

        let dayString = Self.dayString(for: date)
        let initial = """
            ---
            date: \(dayString)
            ---


            """
        try initial.data(using: .utf8)!.write(to: url, options: .atomic)
    }

    /// The "YYYY-MM-DD" string for `date` in UTC.
    static func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    /// The "HH:MM" string for `date` in UTC.
    static func timeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    /// Append `entry` to the journal file for `date`'s day, creating the file
    /// if it does not exist. Internal helper used by all four append methods.
    func appendRaw(_ entry: String, for date: Date) async throws {
        try await ensureJournalExists(for: date)
        let url = journalURL(for: date)
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let separator = existing.hasSuffix("\n\n") ? "" : (existing.hasSuffix("\n") ? "\n" : "\n\n")
        let combined = existing + separator + entry + "\n"
        try combined.data(using: .utf8)!.write(to: url, options: .atomic)
    }
}
