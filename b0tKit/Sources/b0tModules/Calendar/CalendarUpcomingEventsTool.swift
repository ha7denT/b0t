import EventKit
import Foundation
import FoundationModels
import b0tBrain
import b0tCore

/// Returns events on the user's calendar within a lookahead window.
///
/// Read-only. Backed by `EventKitStore.events(matching:)`. The window
/// defaults to the Module's configured `lookahead_hours` parameter; the
/// model may override per-call.
///
/// On `permissionDenied: true`, returns an empty array; the model addresses
/// the denial in its own voice (see ContextAssembler permission addendum,
/// T25).
public struct CalendarUpcomingEventsTool: Tool, PermissionAware, Sendable {
    public let name = "calendar.upcoming_events"
    public let description =
        "Returns events on the user's calendar within the given lookahead window."
    public var requiresPermission: Bool { true }

    @Generable
    public struct Arguments: Sendable {
        @Guide(description: "Lookahead window in hours. Defaults to module-configured lookahead_hours.")
        public let windowHours: Int?
        public init(windowHours: Int? = nil) { self.windowHours = windowHours }
    }

    @Generable
    public struct Output: Sendable {
        public let events: [Event]
        public let permissionDenied: Bool
        public init(events: [Event], permissionDenied: Bool) {
            self.events = events
            self.permissionDenied = permissionDenied
        }
    }

    @Generable
    public struct Event: Sendable {
        @Guide(description: "Event title.")
        public let title: String
        @Guide(description: "ISO-8601 UTC start timestamp.")
        public let startISO: String
        @Guide(description: "ISO-8601 UTC end timestamp.")
        public let endISO: String
        @Guide(description: "Optional location string.")
        public let location: String?
        @Guide(description: "Calendar name (e.g., 'Personal', 'Work').")
        public let calendarName: String
        @Guide(description: "True if the event is marked tentative on the calendar.")
        public let isTentative: Bool

        public init(
            title: String,
            startISO: String,
            endISO: String,
            location: String?,
            calendarName: String,
            isTentative: Bool
        ) {
            self.title = title
            self.startISO = startISO
            self.endISO = endISO
            self.location = location
            self.calendarName = calendarName
            self.isTentative = isTentative
        }
    }

    private let store: any EventKitStore
    private let gate: PermissionGate
    private let clock: any Clock
    private let defaultLookaheadHours: Int

    package init(
        store: any EventKitStore,
        gate: PermissionGate,
        clock: any Clock = SystemClock(),
        defaultLookaheadHours: Int = 24
    ) {
        self.store = store
        self.gate = gate
        self.clock = clock
        self.defaultLookaheadHours = defaultLookaheadHours
    }

    public func call(arguments: Arguments) async throws -> Output {
        guard await gate.ensure(.calendar) else {
            print("[b0t] calendar.upcoming_events: permissionDenied=true (gate refused)")
            return Output(events: [], permissionDenied: true)
        }
        let window = max(1, arguments.windowHours ?? defaultLookaheadHours)
        let now = clock.now()
        let end = now.addingTimeInterval(TimeInterval(window) * 3600)
        print(
            "[b0t] calendar.upcoming_events: window=\(window)h, now=\(now), end=\(end)"
        )
        let calendars = store.calendars(for: .event)
        print("[b0t] calendar.upcoming_events: \(calendars.count) calendars visible:")
        for cal in calendars {
            print("[b0t]   - '\(cal.title)' (type=\(cal.type.rawValue), source=\(cal.source.title))")
        }
        // Diagnostic: also probe a 7-day window to distinguish "no events
        // anywhere" from "event outside our 24h window".
        let weekEnd = now.addingTimeInterval(7 * 24 * 3600)
        let weekPredicate = store.predicateForEvents(
            withStart: now.addingTimeInterval(-7 * 24 * 3600),
            end: weekEnd,
            calendars: nil
        )
        let weekRaw = await store.events(matching: weekPredicate)
        print("[b0t] calendar.upcoming_events: ±7-day probe found \(weekRaw.count) events")
        for ek in weekRaw.prefix(10) {
            print(
                "[b0t]   probe: '\(ek.title ?? "(untitled)")' \(ek.startDate) → \(ek.endDate) calendar='\(ek.calendar?.title ?? "?")'"
            )
        }

        // EventKit refuses any predicate not built via its own factory:
        // `EKEventStore.eventsMatchingPredicate:` throws NSInvalidArgumentException
        // on a generic NSPredicate. Use the store's typed builder. The fake
        // returns its scriptedEvents wholesale; the live impl forwards to
        // `EKEventStore.predicateForEvents(withStart:end:calendars:)`.
        //
        // The in-memory filter uses overlap semantics matching the predicate:
        // an event whose end is after `now` and whose start is before `end`
        // intersects the window. This includes ongoing events that began
        // before `now` (e.g. a meeting that started at 9am when the user
        // asks at 11am) — strict `startDate >= now` would have excluded
        // them. The fake's scriptedEvents pass through; the canceled
        // filter remains because EventKit returns canceled events too.
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let raw = await store.events(matching: predicate)
        print("[b0t] calendar.upcoming_events: raw count=\(raw.count)")
        for ek in raw {
            print(
                "[b0t]   - \(ek.title ?? "(untitled)") start=\(ek.startDate) end=\(ek.endDate) status=\(ek.status.rawValue)"
            )
        }
        let filtered =
            raw
            .filter { $0.endDate >= now && $0.startDate <= end }
            .filter { $0.status != .canceled }
        print("[b0t] calendar.upcoming_events: filtered count=\(filtered.count)")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let events = filtered.map { ek in
            Event(
                title: ek.title ?? "(untitled)",
                startISO: formatter.string(from: ek.startDate),
                endISO: formatter.string(from: ek.endDate),
                location: (ek.location?.isEmpty == false) ? ek.location : nil,
                calendarName: ek.calendar?.title ?? "",
                isTentative: ek.status == .tentative
            )
        }
        return Output(events: events, permissionDenied: false)
    }
}

extension CalendarUpcomingEventsTool {
    /// Producer for `ToolCallRecord` summaries. Used by the live client
    /// adapter when constructing records from typed Arguments/Output.
    public static func summarize(_ arguments: Arguments) -> String {
        "windowHours: \(arguments.windowHours.map(String.init) ?? "default")"
    }

    public static func summarize(_ output: Output) -> String {
        "\(output.events.count) events, permissionDenied: \(output.permissionDenied)"
    }
}
