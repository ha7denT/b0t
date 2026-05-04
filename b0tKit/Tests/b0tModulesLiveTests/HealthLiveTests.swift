#if canImport(HealthKit) && os(iOS)
    import XCTest
    import HealthKit
    @testable import b0tModules

    final class HealthLiveTests: XCTestCase {
        override func setUpWithError() throws {
            try XCTSkipUnless(
                ProcessInfo.processInfo.environment["LIVE_TESTS"] == "1",
                "set LIVE_TESTS=1 to run"
            )
        }

        func testHealthStepsTodayAgainstSimulatorHealthStore() async throws {
            let store = LiveHealthStore()
            let gate = PermissionGate(eventKit: LiveEventKitStore(), health: store)
            let tool = HealthStepsTodayTool(store: store, gate: gate)
            let output = try await tool.call(arguments: .init())
            // Can't assert anything specific — HealthKit's denial-hiding means
            // even denied access reports stepCount: 0, permissionDenied: false.
            // Just verify the call returns and the type is right.
            XCTAssertGreaterThanOrEqual(output.stepCount, 0)
        }
    }
#endif
