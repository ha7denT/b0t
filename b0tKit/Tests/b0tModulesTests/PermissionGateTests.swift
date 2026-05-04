import EventKit
import XCTest

@testable import b0tModules

final class PermissionGateTests: XCTestCase {
    func testCalendarGrantedReturnsTrue() async {
        let store = FakeEventKitStore()
        store.scriptedGrant[.event] = true
        let gate = PermissionGate(eventKit: store)
        let granted = await gate.ensure(.calendar)
        XCTAssertTrue(granted)
    }

    func testCalendarDeniedReturnsFalse() async {
        let store = FakeEventKitStore()
        store.scriptedGrant[.event] = false
        let gate = PermissionGate(eventKit: store)
        let granted = await gate.ensure(.calendar)
        XCTAssertFalse(granted)
    }
}
