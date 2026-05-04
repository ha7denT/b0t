import EventKit
import FoundationModels
import XCTest
import b0tCore

@testable import b0tModules

final class RemindersCreateToolTests: XCTestCase {
    private func makeTool(store: FakeEventKitStore, defaultList: String = "b0t") -> RemindersCreateTool {
        let gate = PermissionGate(eventKit: store)
        return RemindersCreateTool(store: store, gate: gate, defaultListName: defaultList)
    }

    func testGrantedAccessSavesReminder() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.reminder] = true
        let cal = EKCalendar(for: .reminder, eventStore: EKEventStore())
        cal.title = "b0t"
        store.scriptedDefaultReminderCalendar = cal
        store.scriptedCalendars = [cal]
        let tool = makeTool(store: store)
        let output = try await tool.call(
            arguments: .init(
                title: "email Lin",
                dueDateISO: nil,
                notes: nil,
                listName: nil
            ))
        XCTAssertNotNil(output.reminderID)
        XCTAssertEqual(output.listName, "b0t")
        XCTAssertFalse(output.permissionDenied)
        XCTAssertNil(output.saveError)
        XCTAssertEqual(store.savedReminders.count, 1)
        XCTAssertEqual(store.savedReminders[0].title, "email Lin")
    }

    func testDeniedAccessReturnsPermissionDenied() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.reminder] = false
        let tool = makeTool(store: store)
        let output = try await tool.call(
            arguments: .init(
                title: "x", dueDateISO: nil, notes: nil, listName: nil
            ))
        XCTAssertNil(output.reminderID)
        XCTAssertTrue(output.permissionDenied)
        XCTAssertEqual(store.savedReminders.count, 0)
    }

    func testListNameFallsBackToDefault() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.reminder] = true
        let cal = EKCalendar(for: .reminder, eventStore: EKEventStore())
        cal.title = "Other"
        store.scriptedDefaultReminderCalendar = cal
        store.scriptedCalendars = [cal]  // no calendar named "b0t" exists
        let tool = makeTool(store: store, defaultList: "b0t")
        let output = try await tool.call(
            arguments: .init(
                title: "email Lin", dueDateISO: nil, notes: nil, listName: nil
            ))
        // No "b0t" list found → falls back to default-for-new-reminders ("Other")
        XCTAssertEqual(output.listName, "Other")
    }

    func testToolNameIsRemindersCreate() {
        let tool = makeTool(store: FakeEventKitStore())
        XCTAssertEqual(tool.name, "reminders.create")
    }
}
