import SwiftUI
import XCTest

import b0tBrain

@testable import b0tHome

@MainActor
final class BPMSliderTests: XCTestCase {
    func test_bpmSlider_rendersWithLabel() {
        var captured: YAMLValue?
        let view = BPMSlider(value: 4) { newValue in
            captured = newValue
        }
        // smoke: view constructs, label format known.
        _ = view.body
        // simulate a change:
        view.commit(8)
        if case .int(let v) = captured {
            XCTAssertEqual(v, 8)
        } else {
            XCTFail("expected int value, got \(String(describing: captured))")
        }
    }

    func test_bpmSlider_clampsToValidRange() {
        var captured: YAMLValue?
        let view = BPMSlider(value: 4) { captured = $0 }
        view.commit(20)  // out of range — should clamp
        if case .int(let v) = captured {
            XCTAssertLessThanOrEqual(v, 12)
            XCTAssertGreaterThanOrEqual(v, 1)
        }
    }
}
