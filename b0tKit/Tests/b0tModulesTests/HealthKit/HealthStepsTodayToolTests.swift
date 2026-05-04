#if canImport(HealthKit) && os(iOS)
    import XCTest
    import HealthKit
    import FoundationModels
    @testable import b0tModules

    final class HealthStepsTodayToolTests: XCTestCase {
        private func makeTool(store: FakeHealthStore) -> HealthStepsTodayTool {
            let gate = PermissionGate(eventKit: FakeEventKitStore(), health: store)
            return HealthStepsTodayTool(store: store, gate: gate)
        }

        func testGrantedReturnsScriptedSteps() async throws {
            let store = FakeHealthStore()
            store.scriptedGrant = true
            store.scriptedStepsToday = 4523
            let tool = makeTool(store: store)
            let output = try await tool.call(arguments: .init())
            XCTAssertEqual(output.stepCount, 4523)
            XCTAssertFalse(output.permissionDenied)
        }

        func testZeroStepsIsNotInterpretedAsDenial() async throws {
            let store = FakeHealthStore()
            store.scriptedGrant = true
            store.scriptedStepsToday = 0
            let tool = makeTool(store: store)
            let output = try await tool.call(arguments: .init())
            XCTAssertEqual(output.stepCount, 0)
            XCTAssertFalse(output.permissionDenied)
        }

        func testToolNameIsHealthStepsToday() {
            let tool = makeTool(store: FakeHealthStore())
            XCTAssertEqual(tool.name, "health.steps_today")
        }
    }
#endif
