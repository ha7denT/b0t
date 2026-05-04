#if canImport(HealthKit) && os(iOS)
    import XCTest
    import b0tBrain
    import HealthKit
    @testable import b0tModules

    final class HealthModuleTests: XCTestCase {
        private func makeFM(_ pairs: [(String, YAMLValue)]) -> Frontmatter {
            Frontmatter(orderedPairs: pairs)
        }

        func testIDIsHealth() {
            XCTAssertEqual(HealthModule.id, "health")
        }

        func testRequiredPermissionsContainsHealthRead() throws {
            let module = try HealthModule(
                parameters: makeFM([
                    ("module_id", .string("health")),
                    ("read_metrics", .array([.string("steps")])),
                ]),
                store: FakeHealthStore()
            )
            guard case .healthRead(let ids) = module.requiredPermissions[0] else {
                XCTFail("expected .healthRead")
                return
            }
            XCTAssertTrue(ids.contains(.stepCount))
        }

        func testStepsToolPresentWhenStepsInReadMetrics() throws {
            let module = try HealthModule(
                parameters: makeFM([
                    ("module_id", .string("health")),
                    ("read_metrics", .array([.string("steps")])),
                ]),
                store: FakeHealthStore()
            )
            XCTAssertEqual(module.tools.count, 1)
            XCTAssertEqual(module.tools[0].name, "health.steps_today")
        }

        func testStepsToolAbsentWhenStepsNotInReadMetrics() throws {
            let module = try HealthModule(
                parameters: makeFM([
                    ("module_id", .string("health")),
                    ("read_metrics", .array([.string("sleep")])),
                ]),
                store: FakeHealthStore()
            )
            XCTAssertEqual(module.tools.count, 0)
        }
    }
#endif
