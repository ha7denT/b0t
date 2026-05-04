import EventKit
import Foundation

@testable import b0tModules

/// Scriptable in-memory `EventKitStore` for unit tests. Tests set
/// `scriptedGrant[.event] = true/false` to control `requestAccess`'s
/// resolution; `scriptedEvents` controls what `events(matching:)` returns
/// (predicates are ignored — tests filter by setting the array directly).
///
/// `@unchecked Sendable` is required because a `final class` with `var`
/// stored properties is not auto-Sendable. This fake is used exclusively
/// on the main thread in single-threaded unit tests, so the relaxation
/// is safe.
final class FakeEventKitStore: EventKitStore, @unchecked Sendable {
    var scriptedGrant: [EKEntityType: Bool] = [:]
    var scriptedEvents: [EKEvent] = []
    var scriptedCalendars: [EKCalendar] = []
    private(set) var currentStatus: [EKEntityType: EKAuthorizationStatus] = [:]

    func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus {
        currentStatus[entityType] ?? .notDetermined
    }

    func requestAccess(to entityType: EKEntityType) async throws -> Bool {
        let granted = scriptedGrant[entityType] ?? false
        currentStatus[entityType] = granted ? .fullAccess : .denied
        return granted
    }

    func events(matching predicate: NSPredicate) async -> [EKEvent] {
        scriptedEvents
    }

    func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        scriptedCalendars
    }
}
