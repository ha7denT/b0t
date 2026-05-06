import SwiftUI
import XCTest

import b0tBrain

@testable import b0tHome

final class FrontmatterControlTests: XCTestCase {
    func test_dispatcher_returnsRegisteredControlForKnownKey() {
        // bpm is in the semantic registry → BPMSlider expected.
        let control = FrontmatterControlDispatcher.control(
            forKey: "heartbeat_bpm",
            value: .int(4),
            onUpdate: { _ in }
        )
        XCTAssertNotNil(control)
        XCTAssertEqual(control?.kind, .bpmSlider)
    }

    func test_dispatcher_fallsBackToTypeRegistryForUnknownKey() {
        let control = FrontmatterControlDispatcher.control(
            forKey: "something_unknown",
            value: .bool(true),
            onUpdate: { _ in }
        )
        XCTAssertNotNil(control)
        XCTAssertEqual(control?.kind, .toggle)
    }
}
