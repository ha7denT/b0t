import XCTest
import b0tBrain

@testable import b0tModules

final class CalendarModuleTests: XCTestCase {
    private func makeFM(_ pairs: [(String, YAMLValue)]) -> Frontmatter {
        Frontmatter(orderedPairs: pairs)
    }

    func testIDIsCalendar() {
        XCTAssertEqual(CalendarModule.id, "calendar")
    }

    func testDefaultLookaheadIs24WhenAbsent() throws {
        let module = try CalendarModule(
            parameters: makeFM([("module_id", .string("calendar"))]),
            store: FakeEventKitStore()
        )
        XCTAssertEqual(module.tools.count, 1)
    }

    func testFrontmatterLookaheadHoursOverridesDefault() throws {
        let module = try CalendarModule(
            parameters: makeFM([
                ("module_id", .string("calendar")),
                ("lookahead_hours", .int(48)),
            ]),
            store: FakeEventKitStore()
        )
        XCTAssertEqual(module.tools.count, 1)
    }

    func testRequiredPermissionsContainsCalendar() throws {
        let module = try CalendarModule(
            parameters: makeFM([("module_id", .string("calendar"))]),
            store: FakeEventKitStore()
        )
        XCTAssertEqual(module.requiredPermissions, [.calendar])
    }

    func testInvalidLookaheadHoursTypeThrows() {
        XCTAssertThrowsError(
            try CalendarModule(
                parameters: makeFM([
                    ("module_id", .string("calendar")),
                    ("lookahead_hours", .string("not-a-number")),
                ]),
                store: FakeEventKitStore()
            ))
    }
}
