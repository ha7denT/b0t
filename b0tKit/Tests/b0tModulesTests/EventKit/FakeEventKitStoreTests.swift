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

    func testSaveReminderRetainsIt() throws {
        let store = FakeEventKitStore()
        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = "email Lin"
        try store.save(reminder, commit: true)
        XCTAssertEqual(store.savedReminders.count, 1)
        XCTAssertEqual(store.savedReminders[0].title, "email Lin")
    }

    func testFetchRemindersReturnsScripted() async {
        let store = FakeEventKitStore()
        let r = EKReminder(eventStore: EKEventStore())
        r.title = "buy milk"
        store.scriptedReminders = [r]
        let predicate = NSPredicate(value: true)
        let results = await store.fetchReminders(matching: predicate)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "buy milk")
    }

    func testDefaultCalendarForNewRemindersReturnsScripted() {
        let store = FakeEventKitStore()
        let cal = EKCalendar(for: .reminder, eventStore: EKEventStore())
        cal.title = "b0t"
        store.scriptedDefaultReminderCalendar = cal
        XCTAssertEqual(store.defaultCalendarForNewReminders()?.title, "b0t")
    }
}
