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
}
