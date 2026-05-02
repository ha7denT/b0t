import Foundation
import b0tBrain

/// A simple HH:MM value type for parsing quiet-hours boundaries.
///
/// Conforming to `Comparable` so we can use ranges. We model overnight
/// quiet hours (e.g., 22:00–06:30) by checking inclusion in
/// `[start, 24:00) ∪ [00:00, end]` rather than a literal Swift range.
///
/// Named `ClockTime` (not `TimeOfDay`) to avoid colliding with the
/// `TimeOfDay` bucket enum in `Tools/TimeOfDay.swift`. Spec §5.7
/// matches this name.
public struct ClockTime: Sendable, Equatable, Hashable, Comparable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) {
        precondition(hour >= 0 && hour < 24, "hour out of range")
        precondition(minute >= 0 && minute < 60, "minute out of range")
        self.hour = hour
        self.minute = minute
    }

    public static func < (lhs: ClockTime, rhs: ClockTime) -> Bool {
        if lhs.hour != rhs.hour { return lhs.hour < rhs.hour }
        return lhs.minute < rhs.minute
    }

    public init(from date: Date, in timeZone: TimeZone = TimeZone(identifier: "UTC")!) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
    }
}

extension ClockTime {
    init?(parsingHHmm s: String) {
        let parts = s.split(separator: ":")
        guard parts.count == 2,
            let h = Int(parts[0]),
            let m = Int(parts[1]),
            (0..<24).contains(h),
            (0..<60).contains(m)
        else {
            return nil
        }
        self.init(hour: h, minute: m)
    }
}

/// An inclusive clock-time range that supports overnight spans (lowerBound > upperBound).
///
/// Swift's `ClosedRange` enforces `lowerBound <= upperBound`, which precludes
/// representing overnight quiet-hours like 22:00–06:30. `ClockRange` stores the
/// two bounds without that constraint and exposes `lowerBound`/`upperBound` to
/// match `ClosedRange`'s surface API. Use the `...` operator overload below to
/// construct a `ClockRange` from two `ClockTime` values.
public struct ClockRange: Sendable, Equatable {
    public let lowerBound: ClockTime
    public let upperBound: ClockTime

    public init(lower: ClockTime, upper: ClockTime) {
        lowerBound = lower
        upperBound = upper
    }
}

/// Builds a `ClockRange` from two `ClockTime` values, mirroring `ClosedRange`'s
/// `...` operator but without the `lowerBound <= upperBound` precondition.
public func ... (lower: ClockTime, upper: ClockTime) -> ClockRange {
    ClockRange(lower: lower, upper: upper)
}

/// Heartbeat schedule parsed from `heartbeat/schedule.md` frontmatter.
///
/// Per spec §5.7, this is structurally parsed (drives timing in code). The
/// schedule.md prose is NOT included in the heartbeat prompt — only
/// actions.md is, since actions.md drives per-beat behaviour.
///
/// Quiet-hours range is inclusive on both ends and supports overnight ranges
/// (lowerBound > upperBound is interpreted as "spans midnight").
///
/// `bpm: 0` means scheduled beats are off entirely; event triggers still fire.
public struct HeartbeatSchedule: Sendable, Equatable {
    public let bpm: Int
    public let quietHours: ClockRange?
    public let eventTriggers: Set<EventTriggerKind>
    public let mutable: Bool

    public init(
        bpm: Int,
        quietHours: ClockRange?,
        eventTriggers: Set<EventTriggerKind>,
        mutable: Bool
    ) {
        self.bpm = bpm
        self.quietHours = quietHours
        self.eventTriggers = eventTriggers
        self.mutable = mutable
    }

    public var bpmInterval: Duration? {
        guard bpm > 0 else { return nil }
        return .seconds(bpm * 60)
    }

    public func isQuietHours(at date: Date) -> Bool {
        guard let range = quietHours else { return false }
        let now = ClockTime(from: date)

        if range.lowerBound <= range.upperBound {
            // Normal range: e.g. 09:00–17:00
            return now >= range.lowerBound && now <= range.upperBound
        } else {
            // Overnight range: e.g. 22:00–06:30 spans midnight
            return now >= range.lowerBound || now <= range.upperBound
        }
    }

    public static func parse(_ file: BotFile) throws -> HeartbeatSchedule {
        let bpm = file.frontmatter["heartbeat_bpm"].flatMap { $0.intValue } ?? 30
        let mutable = file.frontmatter["mutable"].flatMap { $0.boolValue } ?? true

        var quietHours: ClockRange?
        if let array = file.frontmatter["quiet_hours"].flatMap({ $0.arrayValue }),
            array.count == 2,
            let startStr = array[0].stringValue,
            let endStr = array[1].stringValue,
            let start = ClockTime(parsingHHmm: startStr),
            let end = ClockTime(parsingHHmm: endStr)
        {
            quietHours = start...end
        }

        var eventTriggers: Set<EventTriggerKind> = []
        if let array = file.frontmatter["event_triggers"].flatMap({ $0.arrayValue }) {
            for item in array {
                if let raw = item.stringValue,
                    let kind = EventTriggerKind(rawValue: raw)
                {
                    eventTriggers.insert(kind)
                }
            }
        }

        return HeartbeatSchedule(
            bpm: bpm,
            quietHours: quietHours,
            eventTriggers: eventTriggers,
            mutable: mutable
        )
    }
}

extension YAMLValue {
    var intValue: Int? {
        if case .int(let v) = self { return v }
        if case .string(let s) = self, let v = Int(s) { return v }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    var arrayValue: [YAMLValue]? {
        if case .array(let v) = self { return v }
        return nil
    }
}
