import SwiftUI
import XCTest

import b0tBrain

@testable import b0tHome

@MainActor
final class QuietHoursPickerTests: XCTestCase {
    func test_quietHours_committingNewRange_passesYAMLArray() {
        var captured: YAMLValue?
        let v = QuietHoursPicker(start: "22:00", end: "06:30") { captured = $0 }
        v.commit(start: "23:00", end: "07:00")
        if case .array(let entries) = captured {
            XCTAssertEqual(entries.count, 2)
        } else {
            XCTFail("expected array, got \(String(describing: captured))")
        }
    }

    func test_quietHours_supportsOvernightRanges() {
        let v = QuietHoursPicker(start: "22:00", end: "06:30") { _ in }
        XCTAssertTrue(v.isOvernight)  // start > end implies overnight wrap
    }
}
