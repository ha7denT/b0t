import XCTest

@testable import b0tBrain

final class FrontmatterTests: XCTestCase {
    func test_yamlValue_scalarEquality() {
        XCTAssertEqual(YAMLValue.string("a"), YAMLValue.string("a"))
        XCTAssertEqual(YAMLValue.int(42), YAMLValue.int(42))
        XCTAssertEqual(YAMLValue.bool(true), YAMLValue.bool(true))
        XCTAssertEqual(YAMLValue.null, YAMLValue.null)
        XCTAssertNotEqual(YAMLValue.int(1), YAMLValue.string("1"))
    }

    func test_yamlValue_dictionaryPreservesOrder() {
        let a = YAMLValue.dictionary([("x", .int(1)), ("y", .int(2))])
        let b = YAMLValue.dictionary([("y", .int(2)), ("x", .int(1))])
        XCTAssertNotEqual(a, b, "ordered dictionary must distinguish key order")
    }

    func test_frontmatter_emptyHasNoKeys() {
        let fm = Frontmatter()
        XCTAssertTrue(fm.keys.isEmpty)
        XCTAssertNil(fm["anything"])
        XCTAssertFalse(fm.contains("anything"))
    }
}
