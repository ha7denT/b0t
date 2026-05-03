import XCTest

@testable import b0tCore

final class HeartbeatSchedulerTests: XCTestCase {
    func test_fake_recordsSubmittedDates() async throws {
        let fake = FakeHeartbeatScheduler()
        let date1 = Date(timeIntervalSince1970: 1_000_000)
        let date2 = Date(timeIntervalSince1970: 2_000_000)

        try await fake.submitNextRequest(earliestBeginDate: date1)
        try await fake.submitNextRequest(earliestBeginDate: date2)

        XCTAssertEqual(fake.submittedDates, [date1, date2])
    }
}
