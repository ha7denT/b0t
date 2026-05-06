import XCTest

import b0tBrain

@testable import b0tHome

@MainActor
final class EnabledToggleTests: XCTestCase {
    func test_enabledToggle_commitsBool() {
        var captured: YAMLValue?
        let t = EnabledToggle(moduleName: "calendar", value: true) { captured = $0 }
        t.commit(false)
        if case .bool(let b) = captured { XCTAssertFalse(b) } else { XCTFail() }
    }
}
