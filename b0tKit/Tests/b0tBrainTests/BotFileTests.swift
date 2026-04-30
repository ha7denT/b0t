import XCTest

@testable import b0tBrain

final class BotFileTests: XCTestCase {
    private func url(_ path: String) -> URL {
        URL(fileURLWithPath: "/tmp/b0t-test/\(path)")
    }

    func test_parse_noFrontmatter() throws {
        let text = "# heading\nbody\n"
        let file = try BotFile(fileURL: url("a.md"), text: text)
        XCTAssertNil(file.parseError)
        XCTAssertTrue(file.frontmatter.keys.isEmpty)
        XCTAssertEqual(file.prose, text)
        XCTAssertEqual(file.originalText, text)
    }

    func test_parse_wellFormedFrontmatter() throws {
        let text = "---\nname: b0t-01\nenabled: true\n---\n# body\n"
        let file = try BotFile(fileURL: url("a.md"), text: text)
        XCTAssertNil(file.parseError)
        XCTAssertEqual(file.frontmatter.keys, ["name", "enabled"])
        XCTAssertEqual(file.frontmatter["name"], .string("b0t-01"))
        XCTAssertEqual(file.prose, "# body\n")
    }

    func test_parse_unterminatedFrontmatter_softFailsAndKeepsProse() throws {
        let text = "---\nname: b0t-01\n# no closing\n"
        let file = try BotFile(fileURL: url("a.md"), text: text)
        XCTAssertEqual(file.parseError, .frontmatterUnterminated(url("a.md")))
        XCTAssertTrue(file.frontmatter.keys.isEmpty)
        XCTAssertEqual(file.prose, text, "whole file body becomes prose")
    }

    func test_parse_invalidYAML_softFails() throws {
        let text = "---\nkey: : invalid:\n---\n# body\n"
        let file = try BotFile(fileURL: url("a.md"), text: text)
        guard case .frontmatterInvalidYAML(let failingURL, _)? = file.parseError else {
            return XCTFail("expected frontmatterInvalidYAML, got \(String(describing: file.parseError))")
        }
        XCTAssertEqual(failingURL, url("a.md"))
        XCTAssertTrue(file.frontmatter.keys.isEmpty)
        XCTAssertEqual(file.prose, "# body\n")
    }

    // MARK: - Mutations: setFrontmatter

    func test_settingFrontmatter_existingKey_replacesValueByteIdenticalElsewhere() throws {
        let text = "---\nname: b0t-01\nenabled: true\n---\n# body\n"
        let file = try BotFile(fileURL: url("a.md"), text: text)
        let mutated = file.settingFrontmatter("enabled", to: .bool(false))
        XCTAssertEqual(mutated.frontmatter["enabled"], .bool(false))
        XCTAssertEqual(mutated.originalText, "---\nname: b0t-01\nenabled: false\n---\n# body\n")
    }

    func test_settingFrontmatter_newKey_appendsBeforeClosingDelimiter() throws {
        let text = "---\nname: b0t-01\n---\n# body\n"
        let file = try BotFile(fileURL: url("a.md"), text: text)
        let mutated = file.settingFrontmatter("verbosity", to: .int(3))
        XCTAssertEqual(mutated.frontmatter["verbosity"], .int(3))
        XCTAssertTrue(
            mutated.originalText.contains("name: b0t-01\nverbosity: 3\n---\n"),
            "got: \(mutated.originalText)"
        )
    }

    func test_settingFrontmatter_onBrokenFrontmatter_isNoOp() throws {
        let text = "---\nkey: : invalid:\n---\n# body\n"
        let file = try BotFile(fileURL: url("a.md"), text: text)
        XCTAssertNotNil(file.parseError)
        let mutated = file.settingFrontmatter("anything", to: .bool(true))
        XCTAssertEqual(mutated.originalText, file.originalText)
        XCTAssertEqual(mutated.parseError, file.parseError)
    }

    // MARK: - Mutations: removeFrontmatter

    func test_removingFrontmatter_existingKey_zapsLine() throws {
        let text = "---\nname: b0t-01\nenabled: true\n---\n# body\n"
        let file = try BotFile(fileURL: url("a.md"), text: text)
        let mutated = file.removingFrontmatter("enabled")
        XCTAssertNil(mutated.frontmatter["enabled"])
        XCTAssertEqual(mutated.originalText, "---\nname: b0t-01\n---\n# body\n")
    }

    func test_removingFrontmatter_missingKey_isNoOp() throws {
        let text = "---\nname: b0t-01\n---\n# body\n"
        let file = try BotFile(fileURL: url("a.md"), text: text)
        let mutated = file.removingFrontmatter("not-there")
        XCTAssertEqual(mutated.originalText, text)
    }

    // MARK: - Mutation correctness regressions

    func test_settingFrontmatter_stringStartingWithDash_isQuoted() throws {
        let file = try BotFile(fileURL: url("a.md"), text: "---\nk: original\n---\n")
        let mutated = file.settingFrontmatter("k", to: .string("- item"))
        XCTAssertEqual(
            mutated.frontmatter["k"], .string("- item"),
            "leading dash must be quoted; got: \(mutated.originalText)")
    }

    func test_settingFrontmatter_stringLikeBoolKeyword_isQuoted() throws {
        let file = try BotFile(fileURL: url("a.md"), text: "---\nk: original\n---\n")
        let mutated = file.settingFrontmatter("k", to: .string("true"))
        XCTAssertEqual(
            mutated.frontmatter["k"], .string("true"),
            "string 'true' must be quoted; got: \(mutated.originalText)")
    }

    func test_settingFrontmatter_stringLikeInteger_isQuoted() throws {
        let file = try BotFile(fileURL: url("a.md"), text: "---\nk: original\n---\n")
        let mutated = file.settingFrontmatter("k", to: .string("12345"))
        XCTAssertEqual(
            mutated.frontmatter["k"], .string("12345"),
            "numeric-looking string must be quoted; got: \(mutated.originalText)")
    }

    func test_settingFrontmatter_stringLikeNull_isQuoted() throws {
        let file = try BotFile(fileURL: url("a.md"), text: "---\nk: original\n---\n")
        let mutated = file.settingFrontmatter("k", to: .string("null"))
        XCTAssertEqual(mutated.frontmatter["k"], .string("null"))
    }

    func test_settingFrontmatter_doubleNaN_emitsCanonicalYAML() throws {
        let file = try BotFile(fileURL: url("a.md"), text: "---\nk: 0\n---\n")
        let mutated = file.settingFrontmatter("k", to: .double(.nan))
        XCTAssertTrue(
            mutated.originalText.contains(".nan"),
            "NaN must emit as .nan; got: \(mutated.originalText)")
    }

    func test_settingFrontmatter_doubleInfinity_emitsCanonicalYAML() throws {
        let file = try BotFile(fileURL: url("a.md"), text: "---\nk: 0\n---\n")
        let mutated = file.settingFrontmatter("k", to: .double(.infinity))
        XCTAssertTrue(mutated.originalText.contains(".inf"))
    }

    func test_settingFrontmatter_sameListValue_isByteIdenticalNoop() throws {
        let text = "---\nquiet_hours: [22:00, 06:30]\n---\n# body\n"
        let file = try BotFile(fileURL: url("a.md"), text: text)
        let original = try XCTUnwrap(file.frontmatter["quiet_hours"])
        let mutated = file.settingFrontmatter("quiet_hours", to: original)
        XCTAssertEqual(
            mutated.originalText, text,
            "no-op set must preserve original bytes per §6.5(3)")
    }

    func test_settingFrontmatter_sameScalarValue_isByteIdenticalNoop() throws {
        let text = "---\nname: b0t-01  # the user's b0t\nenabled: true\n---\n"
        let file = try BotFile(fileURL: url("a.md"), text: text)
        let mutated = file.settingFrontmatter(
            "name", to: try XCTUnwrap(file.frontmatter["name"])
        )
        XCTAssertEqual(
            mutated.originalText, text,
            "no-op set on commented entry must preserve comment")
    }

    // MARK: - Mutations: prose

    func test_replacingProse_substitutesProseRegionOnly() throws {
        let text = "---\nname: b0t-01\n---\n# old\n"
        let file = try BotFile(fileURL: url("a.md"), text: text)
        let mutated = file.replacingProse(with: "# new\n")
        XCTAssertEqual(mutated.originalText, "---\nname: b0t-01\n---\n# new\n")
        XCTAssertEqual(mutated.frontmatter["name"], .string("b0t-01"))
    }

    func test_replacingProse_onFileWithoutFrontmatter() throws {
        let text = "# only prose\n"
        let file = try BotFile(fileURL: url("a.md"), text: text)
        let mutated = file.replacingProse(with: "replaced\n")
        XCTAssertEqual(mutated.originalText, "replaced\n")
    }

    func test_appendingProseSection_addsHeadingAndBody() throws {
        let text = "---\nk: v\n---\n# old\n"
        let file = try BotFile(fileURL: url("a.md"), text: text)
        let mutated = file.appendingProseSection(heading: "new section", body: "some text")
        XCTAssertEqual(mutated.prose, "# old\n\n## new section\n\nsome text\n")
        XCTAssertEqual(
            mutated.originalText,
            "---\nk: v\n---\n# old\n\n## new section\n\nsome text\n"
        )
    }

    func test_appendingProseSection_proseWithoutTrailingNewline_normalisesSeparator() throws {
        let text = "---\nk: v\n---\n# old"
        let file = try BotFile(fileURL: url("a.md"), text: text)
        let mutated = file.appendingProseSection(heading: "h", body: "b")
        XCTAssertEqual(mutated.prose, "# old\n\n## h\n\nb\n")
    }

    func test_appendingProseSection_proseWithMultipleTrailingNewlines_normalisesSeparator() throws {
        let text = "---\nk: v\n---\n# old\n\n\n"
        let file = try BotFile(fileURL: url("a.md"), text: text)
        let mutated = file.appendingProseSection(heading: "h", body: "b")
        XCTAssertEqual(mutated.prose, "# old\n\n## h\n\nb\n")
    }

    func test_appendingProseSection_emptyProse_omitsLeadingSeparator() throws {
        let text = "---\nk: v\n---\n"
        let file = try BotFile(fileURL: url("a.md"), text: text)
        let mutated = file.appendingProseSection(heading: "h", body: "b")
        XCTAssertEqual(mutated.prose, "## h\n\nb\n")
    }
}
