#if canImport(HealthKit) && os(iOS)
    import HealthKit
    import XCTest

    @testable import b0tModules

    final class FakeHealthStoreTests: XCTestCase {
        func testInitialAuthorizationStatusIsNotDetermined() {
            let store = FakeHealthStore()
            XCTAssertEqual(
                store.authorizationStatus(for: HKQuantityType(.stepCount)), .notDetermined)
        }

        func testRequestAuthorizationFlipsStatus() async throws {
            let store = FakeHealthStore()
            store.scriptedGrant = true
            try await store.requestAuthorization(
                toShare: nil, read: [HKQuantityType(.stepCount)])
            XCTAssertEqual(
                store.authorizationStatus(for: HKQuantityType(.stepCount)), .sharingAuthorized)
        }

        func testStepsTodayReturnsScripted() async throws {
            let store = FakeHealthStore()
            store.scriptedStepsToday = 4523
            let count = try await store.stepsToday()
            XCTAssertEqual(count, 4523)
        }
    }
#endif
