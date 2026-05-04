#if os(iOS)
    import XCTest
    import EventKit
    @testable import b0tModules

    final class CalendarLiveTests: XCTestCase {
        override func setUpWithError() throws {
            try XCTSkipUnless(
                ProcessInfo.processInfo.environment["LIVE_TESTS"] == "1",
                "set LIVE_TESTS=1 to run"
            )
        }

        func testCalendarUpcomingEventsAgainstSimulatorEventStore() async throws {
            let store = LiveEventKitStore()
            let gate = PermissionGate(eventKit: store)
            let granted = await gate.ensure(.calendar)
            try XCTSkipUnless(granted, "no calendar access in this run")
            let tool = CalendarUpcomingEventsTool(store: store, gate: gate)
            let output = try await tool.call(arguments: .init(windowHours: 24))
            XCTAssertFalse(output.permissionDenied)
            // Don't assert events.count — depends on simulator state. Just
            // verify the call completed without throwing and the type is right.
        }
    }
#endif
