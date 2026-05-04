import XCTest
@testable import b0tBrain

final class ToolCallRecordTests: XCTestCase {
    func testInitAndAccessors() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let record = ToolCallRecord(
            toolName: "calendar.upcoming_events",
            argumentsSummary: "windowHours: 24",
            outputSummary: "2 events, permissionDenied: false",
            timestamp: date
        )
        XCTAssertEqual(record.toolName, "calendar.upcoming_events")
        XCTAssertEqual(record.argumentsSummary, "windowHours: 24")
        XCTAssertEqual(record.outputSummary, "2 events, permissionDenied: false")
        XCTAssertEqual(record.timestamp, date)
    }

    func testEquatable() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let a = ToolCallRecord(toolName: "x", argumentsSummary: "a", outputSummary: "b", timestamp: date)
        let b = ToolCallRecord(toolName: "x", argumentsSummary: "a", outputSummary: "b", timestamp: date)
        let c = ToolCallRecord(toolName: "y", argumentsSummary: "a", outputSummary: "b", timestamp: date)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testIsSendable() {
        // Compile-time check: storing in a Sendable context.
        let _: any Sendable = ToolCallRecord(
            toolName: "x", argumentsSummary: "y", outputSummary: "z", timestamp: Date()
        )
    }
}
