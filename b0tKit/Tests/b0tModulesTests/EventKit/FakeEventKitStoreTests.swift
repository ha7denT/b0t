import EventKit
import XCTest

@testable import b0tModules

final class FakeEventKitStoreTests: XCTestCase {
    func testInitialAuthorizationStatusIsNotDetermined() {
        let store = FakeEventKitStore()
        XCTAssertEqual(store.authorizationStatus(for: .event), .notDetermined)
    }

    func testGrantingAccessFlipsStatusAndReturnsTrue() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.event] = true
        let granted = try await store.requestAccess(to: .event)
        XCTAssertTrue(granted)
        XCTAssertEqual(store.authorizationStatus(for: .event), .fullAccess)
    }

    func testDenyingAccessFlipsStatusAndReturnsFalse() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.event] = false
        let granted = try await store.requestAccess(to: .event)
        XCTAssertFalse(granted)
        XCTAssertEqual(store.authorizationStatus(for: .event), .denied)
    }

    func testEventsMatchingReturnsScriptedEvents() async {
        let store = FakeEventKitStore()
        let calendar = EKCalendar(for: .event, eventStore: EKEventStore())
        calendar.title = "Personal"
        let event = EKEvent(eventStore: EKEventStore())
        event.title = "coffee with Lin"
        event.startDate = Date(timeIntervalSince1970: 1_700_000_000)
        event.endDate = event.startDate.addingTimeInterval(1800)
        event.calendar = calendar
        store.scriptedEvents = [event]
        let predicate = NSPredicate(value: true)
        let results = await store.events(matching: predicate)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "coffee with Lin")
    }
}
