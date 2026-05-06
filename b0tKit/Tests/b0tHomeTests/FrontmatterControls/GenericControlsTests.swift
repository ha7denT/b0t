import SwiftUI
import XCTest

import b0tBrain

@testable import b0tHome

@MainActor
final class GenericControlsTests: XCTestCase {
    func test_toggle_commitsBool() {
        var captured: YAMLValue?
        let v = BoolToggleControl(label: "enabled", value: true, onCommit: { captured = $0 })
        v.commit(false)
        if case .bool(let b) = captured { XCTAssertFalse(b) } else { XCTFail() }
    }

    func test_stepper_commitsInt() {
        var captured: YAMLValue?
        let v = StepperControl(label: "level", value: 3, onCommit: { captured = $0 })
        v.commit(5)
        if case .int(let i) = captured { XCTAssertEqual(i, 5) } else { XCTFail() }
    }

    func test_textField_commitsString() {
        var captured: YAMLValue?
        let v = TextFieldControl(label: "name", value: "old", onCommit: { captured = $0 })
        v.commit("new")
        if case .string(let s) = captured { XCTAssertEqual(s, "new") } else { XCTFail() }
    }
}
