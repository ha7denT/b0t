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
            return Output(events: [], permissionDenied: true)
        }
        let window = max(1, arguments.windowHours ?? defaultLookaheadHours)
        let now = clock.now()
        let end = now.addingTimeInterval(TimeInterval(window) * 3600)

        // EventKit refuses any predicate not built via its own factory:
        // `EKEventStore.eventsMatchingPredicate:` throws NSInvalidArgumentException
        // on a generic NSPredicate. Use the store's typed builder. The fake
        // returns its scriptedEvents wholesale; the live impl forwards to
        // `EKEventStore.predicateForEvents(withStart:end:calendars:)`. The
        // in-memory `.filter { startDate ... }` is still belt-and-braces:
        // the predicate may include events that overlap the window from
        // before `now`, and we want strictly upcoming.
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let raw = await store.events(matching: predicate)
        let filtered =
            raw
            .filter { $0.startDate >= now && $0.startDate <= end }
            .filter { $0.status != .canceled }

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
