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
        try Data(initial.utf8).write(to: url, options: [.atomic])
    }

    /// The "YYYY-MM-DD" string for `date` in UTC.
    static func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        return formatter.string(from: date)
    }

    /// The "HH:MM" string for `date` in UTC.
    static func timeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
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
        try Data(combined.utf8).write(to: url, options: [.atomic])
    }

    public func appendConversationTurn(
        prompt: String,
        response: ConversationResponse,
        stateDelta: StateDelta,
        turnNumber: Int
    ) async throws {
        let date = clock.now()
        let timeString = Self.timeString(for: date)
        let stateDeltaText = Self.formatStateDelta(stateDelta, bot: bot)

        var lines: [String] = [
            "## \(timeString) \u{2014} turn \(turnNumber)",
            "",
            "**observed:** user said: \(prompt)",
            "**decided:** \(response.text)",
        ]

        if let mood = response.mood {
            lines.append("**mood:** \(mood.rawValue)")
        }

        if !response.memoryObservations.isEmpty {
            lines.append("**memory_observations:**")
            for obs in response.memoryObservations {
                lines.append("- (\(obs.importance.rawValue)) \(obs.about): \(obs.what)")
            }
        }

        lines.append("**state_delta:** \(stateDeltaText)")

        let entry = lines.joined(separator: "\n")
        try await appendRaw(entry, for: date)
    }

    public func appendTick(
        decision: TickDecision,
        stateDelta: StateDelta,
        beatNumber: Int
    ) async throws {
        let date = clock.now()
        let timeString = Self.timeString(for: date)
        let stateDeltaText = Self.formatStateDelta(stateDelta, bot: bot)

        var lines: [String] = [
            "## \(timeString) \u{2014} heartbeat \(beatNumber)",
            "",
            "**observed:** \(decision.observed)",
            "**considered:** \(decision.considered.joined(separator: ", "))",
            "**decided:** \(decision.decided)",
            "**why:** \(decision.why)",
            "**acted:** \(decision.acted)",
        ]

        if let mood = decision.mood {
            lines.append("**mood:** \(mood.rawValue)")
        }
        if let organ = decision.organUsed {
            lines.append("**organ_used:** \(organ)")
        }
        if !decision.memoryObservations.isEmpty {
            lines.append("**memory_observations:**")
            for obs in decision.memoryObservations {
                lines.append("- (\(obs.importance.rawValue)) \(obs.about): \(obs.what)")
            }
        }
        lines.append("**state_delta:** \(stateDeltaText)")

        let entry = lines.joined(separator: "\n")
        try await appendRaw(entry, for: date)
    }

    public func appendSuppressed(
        reason: SuppressionReason,
        beatNumber: Int
    ) async throws {
        let date = clock.now()
        let timeString = Self.timeString(for: date)

        let reasonText: String
        switch reason {
        case .quietHours: reasonText = "quiet hours"
        case .modelUnavailable: reasonText = "model unavailable"
        }

        let entry = """
            ## \(timeString) \u{2014} heartbeat \(beatNumber) \u{2014} suppressed

            **reason:** \(reasonText)
            **state_delta:** none
            """
        try await appendRaw(entry, for: date)
    }

    public func appendError(
        error: Error,
        kind: EntryKind
    ) async throws {
        let date = clock.now()
        let timeString = Self.timeString(for: date)
        let header: String
        switch kind {
        case .turn(let n): header = "## \(timeString) \u{2014} turn \(n) \u{2014} error"
        case .heartbeat(let n): header = "## \(timeString) \u{2014} heartbeat \(n) \u{2014} error"
        }
        let errorText = describeError(error)
        let entry = """
            \(header)

            **error:** \(errorText)
            **state_delta:** none
            """
        try await appendRaw(entry, for: date)
    }

    private func describeError(_ error: Error) -> String {
        if let lme = error as? LanguageModelClientError {
            switch lme {
            case .modelUnavailable: return "modelUnavailable"
            case .exceededContextWindowSize(let n): return "exceededContextWindowSize(\(n))"
            case .sessionFailed(let d): return "sessionFailed: \(d)"
            case .malformedGenerableOutput(let d): return "malformedGenerableOutput: \(d)"
            }
        }
        if let described = (error as? CustomStringConvertible)?.description {
            return described
        }
        return String(describing: error)
    }

    static func formatStateDelta(_ delta: StateDelta, bot: Bot) -> String {
        if delta.writtenFiles.isEmpty && delta.wouldNotifyText == nil {
            return "none"
        }
        let pathPrefix = bot.rootURL.path
        let relative = delta.writtenFiles.map { url -> String in
            let path = url.path
            if path.hasPrefix(pathPrefix) {
                // Strip "<bot-root>/" prefix → e.g., "memory/recent.md"
                return String(path.dropFirst(pathPrefix.count + 1))
            }
            return url.lastPathComponent
        }.sorted()
        var parts = relative
        if let notify = delta.wouldNotifyText {
            parts.append("would_notify: \(notify)")
        }
        return parts.joined(separator: ", ")
    }
}
