import FoundationModels
import XCTest
import b0tCore
@testable import b0tModules

final class TimeAwarenessToolTests: XCTestCase {
    final class FixedClock: b0tCore.Clock, @unchecked Sendable {
        var date: Date
        init(_ date: Date) { self.date = date }
        func now() -> Date { date }
    }

    func test_bucket_morningBoundaries() {
        XCTAssertEqual(bucketAt(hour: 6, minute: 29), .night)
        XCTAssertEqual(bucketAt(hour: 6, minute: 30), .morning)
        XCTAssertEqual(bucketAt(hour: 11, minute: 59), .morning)
        XCTAssertEqual(bucketAt(hour: 12, minute: 0), .afternoon)
    }

    func test_bucket_eveningBoundaries() {
        XCTAssertEqual(bucketAt(hour: 17, minute: 59), .afternoon)
        XCTAssertEqual(bucketAt(hour: 18, minute: 0), .evening)
        XCTAssertEqual(bucketAt(hour: 21, minute: 59), .evening)
        XCTAssertEqual(bucketAt(hour: 22, minute: 0), .night)
        XCTAssertEqual(bucketAt(hour: 0, minute: 0), .night)
        XCTAssertEqual(bucketAt(hour: 3, minute: 0), .night)
    }

    func test_call_returnsCurrentTimeAndBucket() async throws {
        let date = ISO8601DateFormatter().date(from: "2026-05-01T14:30:00Z")!
        let tool = TimeAwarenessTool(clock: FixedClock(date))

        let output = try await tool.call(arguments: TimeAwarenessTool.Arguments())

        XCTAssertEqual(output.timeOfDay, .afternoon)
        XCTAssertEqual(output.isoTimestamp, "2026-05-01T14:30:00Z")
    }

    private func bucketAt(hour: Int, minute: Int) -> TimeOfDay {
        var components = DateComponents()
        components.year = 2026; components.month = 5; components.day = 1
        components.hour = hour; components.minute = minute
        components.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: components)!
        return TimeOfDay.bucket(for: date)
    }
}
