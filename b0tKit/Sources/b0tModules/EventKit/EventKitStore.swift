@preconcurrency import EventKit
import Foundation

/// Wrapper to suppress sendability warnings for EventKit arrays in async context.
/// Safe because EKEventStore callbacks execute synchronously.
struct SendableRemindersBox: @unchecked Sendable {
    let reminders: [EKReminder]
}

/// The seam through which `b0tModules`'s calendar and reminder tools talk
/// to EventKit. Two implementations exist: `LiveEventKitStore` (wraps
/// Apple's `EKEventStore`) and `FakeEventKitStore` (test-target visible,
/// scriptable in-memory state).
///
/// Slice 4 (this task) ships only the calendar surface. Reminder methods
/// land in Slice 5 / T18 by extending this protocol.
public protocol EventKitStore: Sendable {
    func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus
    func requestAccess(to entityType: EKEntityType) async throws -> Bool

    // Calendar
    func events(matching predicate: NSPredicate) async -> [EKEvent]
    func calendars(for entityType: EKEntityType) -> [EKCalendar]
    func predicateForEvents(
        withStart startDate: Date,
        end endDate: Date,
        calendars: [EKCalendar]?
    ) -> NSPredicate

    // Reminders (T18)
    func save(_ reminder: EKReminder, commit: Bool) throws
    func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder]
    func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate
    func defaultCalendarForNewReminders() -> EKCalendar?
}

/// The production `EventKitStore`. Wraps a single `EKEventStore`.
///
/// `EKEventStore` does not conform to `Sendable`. The property is declared
/// `nonisolated(unsafe)` because `EKEventStore` is thread-safe by Apple's
/// own documentation and the instance is only ever read — never mutated —
/// after initialisation, making the suppression correct.
public struct LiveEventKitStore: EventKitStore {
    nonisolated(unsafe) private let store: EKEventStore

    public init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    public func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: entityType)
    }

    public func requestAccess(to entityType: EKEntityType) async throws -> Bool {
        switch entityType {
        case .event:
            return try await store.requestFullAccessToEvents()
        case .reminder:
            return try await store.requestFullAccessToReminders()
        @unknown default:
            return false
        }
    }

    public func events(matching predicate: NSPredicate) async -> [EKEvent] {
        store.events(matching: predicate)
    }

    public func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        store.calendars(for: entityType)
    }

    public func predicateForEvents(
        withStart startDate: Date,
        end endDate: Date,
        calendars: [EKCalendar]?
    ) -> NSPredicate {
        store.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
    }

    public func save(_ reminder: EKReminder, commit: Bool) throws {
        try store.save(reminder, commit: commit)
    }

    public func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { cont in
            self.store.fetchReminders(matching: predicate) { reminders in
                let box = SendableRemindersBox(reminders: reminders ?? [])
                cont.resume(returning: box.reminders)
            }
        }
    }

    public func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate {
        store.predicateForReminders(in: calendars)
    }

    public func defaultCalendarForNewReminders() -> EKCalendar? {
        store.defaultCalendarForNewReminders()
    }
}
