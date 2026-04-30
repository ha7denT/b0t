import XCTest

@testable import b0tBrain

final class MarkdownSplitterTests: XCTestCase {
    func test_split_noFrontmatter_returnsAllAsProse() throws {
        let text = "# heading\n\nbody\n"
        let result = try MarkdownSplitter.split(text)
        XCTAssertNil(result.frontmatterRange)
        XCTAssertEqual(String(text[result.proseRange]), text)
        XCTAssertNil(result.parseError)
    }

    func test_split_wellFormedFrontmatter() throws {
        let text = "---\nkey: value\n---\n# heading\n"
        let result = try MarkdownSplitter.split(text)
        XCTAssertNotNil(result.frontmatterRange)
        let fm = String(text[result.frontmatterRange!])
        XCTAssertEqual(fm, "key: value")
        XCTAssertEqual(String(text[result.proseRange]), "# heading\n")
        XCTAssertNil(result.parseError)
    }

    func test_split_unterminatedFrontmatter_softFails() throws {
        let text = "---\nkey: value\n# no closing delimiter\n"
        let result = try MarkdownSplitter.split(text)
        XCTAssertNil(result.frontmatterRange)
        XCTAssertEqual(String(text[result.proseRange]), text)
        XCTAssertEqual(result.parseError, .frontmatterUnterminated)
    }

    func test_split_emptyFrontmatter() throws {
        let text = "---\n---\n# body\n"
        let result = try MarkdownSplitter.split(text)
        XCTAssertNotNil(result.frontmatterRange)
        XCTAssertEqual(String(text[result.frontmatterRange!]), "")
        XCTAssertEqual(String(text[result.proseRange]), "# body\n")
    }

    func test_split_frontmatterStartingWithoutDashesIsProse() throws {
        let text = "key: value\n---\nbody\n"
        let result = try MarkdownSplitter.split(text)
        XCTAssertNil(result.frontmatterRange)
        XCTAssertEqual(String(text[result.proseRange]), text)
    }

    func test_split_handlesBOM() throws {
        let text = "\u{FEFF}---\nk: v\n---\nbody\n"
        let result = try MarkdownSplitter.split(text)
        XCTAssertNotNil(result.frontmatterRange, "BOM should be tolerated")
    }
}
