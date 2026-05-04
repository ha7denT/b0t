#if os(iOS)
    import XCTest
    import EventKit
    @testable import b0tModules

    final class RemindersLiveTests: XCTestCase {
        override func setUpWithError() throws {
            try XCTSkipUnless(
                ProcessInfo.processInfo.environment["LIVE_TESTS"] == "1",
                "set LIVE_TESTS=1 to run"
            )
        }

        func testRemindersListAgainstSimulatorEventStore() async throws {
            let store = LiveEventKitStore()
            let gate = PermissionGate(eventKit: store)
            let granted = await gate.ensure(.reminders)
            try XCTSkipUnless(granted, "no reminders access in this run")
            let tool = RemindersListTool(store: store, gate: gate)
            let output = try await tool.call(arguments: .init(window: .today))
            XCTAssertFalse(output.permissionDenied)
            // Don't assert reminders.count — depends on simulator state.
        }

        func testRemindersCreateAgainstSimulatorEventStore() async throws {
            let store = LiveEventKitStore()
            let gate = PermissionGate(eventKit: store)
            let granted = await gate.ensure(.reminders)
            try XCTSkipUnless(granted, "no reminders access in this run")
            let tool = RemindersCreateTool(store: store, gate: gate, defaultListName: "b0t")
            let output = try await tool.call(
                arguments: .init(
                    title: "live test reminder \(Date().timeIntervalSince1970)",
                    dueDateISO: nil,
                    notes: nil,
                    listName: nil
                )
            )
            XCTAssertFalse(output.permissionDenied)
            XCTAssertNotNil(output.reminderID)
            XCTAssertNil(output.saveError)
        }
    }
#endif
