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

    // MARK: - FrontmatterParser

    func test_parser_emptyText_returnsEmpty() throws {
        let result = try FrontmatterParser.parse("")
        XCTAssertTrue(result.frontmatter.keys.isEmpty)
        XCTAssertTrue(result.entries.isEmpty)
    }

    func test_parser_simpleScalars() throws {
        let yaml = "name: b0t-01\nenabled: true\nverbosity: 3"
        let result = try FrontmatterParser.parse(yaml)
        XCTAssertEqual(result.frontmatter.keys, ["name", "enabled", "verbosity"])
        XCTAssertEqual(result.frontmatter["name"], .string("b0t-01"))
        XCTAssertEqual(result.frontmatter["enabled"], .bool(true))
        XCTAssertEqual(result.frontmatter["verbosity"], .int(3))
    }

    func test_parser_listValue() throws {
        let yaml = "muted_calendars: [work, family]"
        let result = try FrontmatterParser.parse(yaml)
        XCTAssertEqual(
            result.frontmatter["muted_calendars"],
            .array([.string("work"), .string("family")])
        )
    }

    func test_parser_invalidYAML_throws() {
        let yaml = "key: : invalid:"
        XCTAssertThrowsError(try FrontmatterParser.parse(yaml)) { error in
            guard let parseError = error as? FrontmatterParser.ParseError else {
                XCTFail("expected FrontmatterParser.ParseError")
                return
            }
            switch parseError {
            case .invalidYAML: break
            }
        }
    }

    func test_parser_entryByteRangesPointToOriginalValueText() throws {
        let yaml = "key: hello world"
        let result = try FrontmatterParser.parse(yaml)
        let entry = try XCTUnwrap(result.entries.first)
        XCTAssertEqual(entry.key, "key")
        XCTAssertEqual(String(yaml[entry.valueRange]), "hello world")
    }

    func test_parser_quotedKeyWithColon_isRejectedNotMisaligned() {
        // A quoted key containing a colon — Yams accepts it, but our line
        // scanner can't recover the key text. The guard should throw rather
        // than silently misalign byte ranges.
        let yaml = "\"weird: key\": value1\nname: value2"
        XCTAssertThrowsError(try FrontmatterParser.parse(yaml)) { error in
            guard let parseError = error as? FrontmatterParser.ParseError else {
                XCTFail("expected FrontmatterParser.ParseError, got \(error)")
                return
            }
            switch parseError {
            case .invalidYAML(let message):
                XCTAssertTrue(
                    message.contains("byte-range scan") || message.contains("unsupported key"),
                    "expected misalignment-guard message, got \(message)"
                )
            }
        }
    }
}
