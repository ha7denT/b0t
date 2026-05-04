@preconcurrency import EventKit
import Foundation

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

    // Reminders methods are added in T18 (Slice 5).
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
}
