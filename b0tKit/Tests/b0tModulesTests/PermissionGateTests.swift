import XCTest
@testable import b0tModules

final class PermissionGateTests: XCTestCase {
    func testActorIsConstructible() async {
        let gate = PermissionGate()
        // No public API to assert against yet — slice 4 is the first slice
        // with a real backend, where behavioural tests land.
        _ = gate
    }
}
