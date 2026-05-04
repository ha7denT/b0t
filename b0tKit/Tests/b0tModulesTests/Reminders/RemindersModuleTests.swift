import XCTest
import b0tBrain

@testable import b0tModules

final class RemindersModuleTests: XCTestCase {
    private func makeFM(_ pairs: [(String, YAMLValue)]) -> Frontmatter {
        Frontmatter(orderedPairs: pairs)
    }

    func testIDIsReminders() {
        XCTAssertEqual(RemindersModule.id, "reminders")
    }

    func testDefaultListIsB0tWhenAbsent() throws {
        let module = try RemindersModule(
            parameters: makeFM([("module_id", .string("reminders"))]),
            store: FakeEventKitStore()
        )
        XCTAssertEqual(module.tools.count, 2)
    }

    func testDefaultListOverride() throws {
        let module = try RemindersModule(
            parameters: makeFM([
                ("module_id", .string("reminders")),
                ("default_list", .string("Personal")),
            ]),
            store: FakeEventKitStore()
        )
        XCTAssertEqual(module.tools.count, 2)
    }

    func testRequiredPermissionsContainsReminders() throws {
        let module = try RemindersModule(
            parameters: makeFM([("module_id", .string("reminders"))]),
            store: FakeEventKitStore()
        )
        XCTAssertEqual(module.requiredPermissions, [.reminders])
    }

    func testInvalidDefaultListTypeThrows() {
        XCTAssertThrowsError(
            try RemindersModule(
                parameters: makeFM([
                    ("module_id", .string("reminders")),
                    ("default_list", .int(42)),
                ]),
                store: FakeEventKitStore()
            ))
    }
}
