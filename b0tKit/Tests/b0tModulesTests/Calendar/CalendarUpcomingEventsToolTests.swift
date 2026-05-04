import EventKit
import FoundationModels
import XCTest
import b0tBrain
import b0tCore

@testable import b0tModules

final class CalendarUpcomingEventsToolTests: XCTestCase {
    private func makeTool(
        store: FakeEventKitStore,
        defaultLookahead: Int = 24
    ) -> CalendarUpcomingEventsTool {
        let gate = PermissionGate(eventKit: store)
        let clock = FixedClock(date: Date(timeIntervalSince1970: 1_700_000_000))
        return CalendarUpcomingEventsTool(
            store: store,
            gate: gate,
            clock: clock,
            defaultLookaheadHours: defaultLookahead
        )
    }

    func testGrantedAccessReturnsEvents() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.event] = true
        let cal = EKCalendar(for: .event, eventStore: EKEventStore())
        cal.title = "Personal"
        let event = EKEvent(eventStore: EKEventStore())
        event.title = "coffee with Lin"
        event.startDate = Date(timeIntervalSince1970: 1_700_000_000 + 3600)
        event.endDate = event.startDate.addingTimeInterval(1800)
        event.calendar = cal
        store.scriptedEvents = [event]

        let tool = makeTool(store: store)
        let output = try await tool.call(arguments: .init(windowHours: 24))
        XCTAssertEqual(output.events.count, 1)
        XCTAssertEqual(output.events[0].title, "coffee with Lin")
        XCTAssertFalse(output.permissionDenied)
    }

    func testDeniedAccessReturnsPermissionDeniedAndEmptyEvents() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.event] = false
        let tool = makeTool(store: store)
        let output = try await tool.call(arguments: .init(windowHours: nil))
        XCTAssertEqual(output.events.count, 0)
        XCTAssertTrue(output.permissionDenied)
    }

    func testToolNameIsCalendarUpcomingEvents() {
        let tool = makeTool(store: FakeEventKitStore())
        XCTAssertEqual(tool.name, "calendar.upcoming_events")
    }

    func testRequiresPermission() {
        let tool = makeTool(store: FakeEventKitStore())
        XCTAssertTrue(tool.requiresPermission)
    }
}

// FixedClock copy — mirrors the one in TimeAwarenessToolTests so the new
// test directory can compile without cross-file imports. Same shape.
private final class FixedClock: b0tCore.Clock, @unchecked Sendable {
    var date: Date
    init(date: Date) { self.date = date }
    func now() -> Date { date }
}
