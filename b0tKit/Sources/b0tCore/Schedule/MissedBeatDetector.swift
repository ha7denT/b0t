import Foundation
import FoundationModels
import b0tBrain

/// Computes the duration since the last journal entry's timestamp.
///
/// Strategy: scan today's journal file for the LAST `## HH:MM —` header
/// line, parse the time, and return `now - last_entry_time`. If today's
/// file doesn't exist, return nil (no journal yet — no gap to surface).
///
/// Phase 2 simplification: we only check today's file. If iOS skipped beats
/// across midnight (last beat 23:59 yesterday, this beat 06:30 today), the
/// detector returns nil because today's file has no prior entries — that's
/// acceptable for Phase 2 (gap surfacing is a polish touch). Phase 4+ may
/// extend the lookback to yesterday's file if needed.
public struct MissedBeatDetector: Sendable {
    private let bot: Bot
    private let store: BotStore

    public init(bot: Bot, store: BotStore) {
        self.bot = bot
        self.store = store
    }

    public func gap(now: Date) async throws -> Duration? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        let day = formatter.string(from: now)

        let url = bot.journal.directoryURL.appendingPathComponent("\(day).md")
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        guard let lastTime = lastEntryTime(in: content, day: day) else {
            return nil
        }
        let interval = now.timeIntervalSince(lastTime)
        guard interval > 0 else { return .seconds(0) }
        return .seconds(Int(interval))
    }

    private func lastEntryTime(in content: String, day: String) -> Date? {
        // Find every "## HH:MM —" header. Take the last one.
        // Em-dash escape \u{2014} matches JournalWriter's writer format byte-exactly.
        let pattern = "##\\s+([0-9]{2}:[0-9]{2})\\s+\u{2014}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)
        guard let last = matches.last,
            let r = Range(last.range(at: 1), in: content)
        else {
            return nil
        }
        let timeString = String(content[r])

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        return formatter.date(from: "\(day) \(timeString)")
    }
}
