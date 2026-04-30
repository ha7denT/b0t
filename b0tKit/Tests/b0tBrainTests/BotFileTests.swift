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
}
