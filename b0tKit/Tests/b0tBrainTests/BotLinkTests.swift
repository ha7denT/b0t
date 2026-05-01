import XCTest
@testable import b0tBrain

final class BotLinkTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("BotLinkTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func test_parseLinks_findsAllInlineLinks() {
        let prose =
            "see [calendar](skills/calendar.md) and [reminders](skills/reminders.md)"
            + " and [docs](https://example.com)"
        let links = BotLink.parse(prose: prose, sourceFileURL: URL(fileURLWithPath: "/tmp/a.md"))
        XCTAssertEqual(links.count, 3)
        XCTAssertEqual(links[0].label, "calendar")
        XCTAssertEqual(links[0].rawTarget, "skills/calendar.md")
    }

    func test_resolve_relativePathToExistingFile() throws {
        let source = tmp.appendingPathComponent("identity/core.md")
        let target = tmp.appendingPathComponent("skills/calendar.md")
        try FileManager.default.createDirectory(
            at: tmp.appendingPathComponent("identity"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: tmp.appendingPathComponent("skills"), withIntermediateDirectories: true)
        try "".write(to: source, atomically: true, encoding: .utf8)
        try "".write(to: target, atomically: true, encoding: .utf8)

        let link = BotLink(label: "calendar", rawTarget: "../skills/calendar.md", sourceFileURL: source)
        switch link.resolution {
        case .botFile(let url):
            XCTAssertEqual(url.standardizedFileURL, target.standardizedFileURL)
        default:
            XCTFail("expected .botFile, got \(link.resolution)")
        }
    }

    func test_resolve_relativePathToMissingFile() {
        let source = tmp.appendingPathComponent("identity/core.md")
        let link = BotLink(label: "x", rawTarget: "../skills/missing.md", sourceFileURL: source)
        if case .botFileMissing = link.resolution {
            // ok
        } else {
            XCTFail("expected .botFileMissing, got \(link.resolution)")
        }
    }

    func test_resolve_externalHTTPSLink() {
        let source = URL(fileURLWithPath: "/tmp/a.md")
        let link = BotLink(label: "site", rawTarget: "https://example.com/x", sourceFileURL: source)
        if case .external = link.resolution {
            // ok
        } else {
            XCTFail("expected .external, got \(link.resolution)")
        }
    }
}
