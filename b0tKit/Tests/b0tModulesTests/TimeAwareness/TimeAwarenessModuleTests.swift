import FoundationModels
import XCTest
import b0tBrain

@testable import b0tModules

final class TimeAwarenessModuleTests: XCTestCase {
    func testIDIsTimeAwareness() {
        XCTAssertEqual(TimeAwarenessModule.id, "time-awareness")
    }

    func testRequiredPermissionsIsEmpty() throws {
        let m = try TimeAwarenessModule(parameters: Frontmatter())
        XCTAssertEqual(m.requiredPermissions.count, 0)
    }

    func testToolsContainsExactlyTimeAwarenessTool() throws {
        let m = try TimeAwarenessModule(parameters: Frontmatter())
        XCTAssertEqual(m.tools.count, 1)
        XCTAssertEqual(m.tools[0].name, "time_awareness")
    }

    func testInitFromFrontmatterAcceptsAnyFrontmatter() throws {
        let fm = Frontmatter(orderedPairs: [
            ("module_id", .string("time-awareness")),
            ("enabled", .bool(true)),
            ("some_extra_key", .string("ignored")),
        ])
        XCTAssertNoThrow(try TimeAwarenessModule(parameters: fm))
    }
}
