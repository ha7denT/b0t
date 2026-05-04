import EventKit
import FoundationModels
import XCTest

@testable import b0tModules

final class RemindersListToolTests: XCTestCase {
    private func makeTool(store: FakeEventKitStore) -> RemindersListTool {
        let gate = PermissionGate(eventKit: store)
        return RemindersListTool(store: store, gate: gate)
    }

    func testGrantedAccessReturnsIncompleteReminders() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.reminder] = true
        let cal = EKCalendar(for: .reminder, eventStore: EKEventStore())
        cal.title = "b0t"
        let r1 = EKReminder(eventStore: EKEventStore())
        r1.title = "buy milk"
        r1.calendar = cal
        let r2 = EKReminder(eventStore: EKEventStore())
        r2.title = "completed already"
        r2.calendar = cal
        r2.isCompleted = true
        store.scriptedReminders = [r1, r2]
        let tool = makeTool(store: store)
        let output = try await tool.call(arguments: .init(window: .today))
        XCTAssertEqual(output.reminders.count, 1)
        XCTAssertEqual(output.reminders[0].title, "buy milk")
    }

    func testDeniedAccessReturnsPermissionDenied() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.reminder] = false
        let tool = makeTool(store: store)
        let output = try await tool.call(arguments: .init(window: nil))
        XCTAssertEqual(output.reminders.count, 0)
        XCTAssertTrue(output.permissionDenied)
    }

    func testToolNameIsRemindersList() {
        let tool = makeTool(store: FakeEventKitStore())
        XCTAssertEqual(tool.name, "reminders.list")
    }
}
