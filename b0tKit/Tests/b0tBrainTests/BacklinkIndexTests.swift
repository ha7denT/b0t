import XCTest

@testable import b0tBrain

final class BacklinkIndexTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("BacklinkTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func test_backlinks_findsFilesLinkingToTarget() async throws {
        let identityDir = tmp.appendingPathComponent("identity")
        let modulesDir = tmp.appendingPathComponent("modules")
        try FileManager.default.createDirectory(at: identityDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: modulesDir, withIntermediateDirectories: true)

        let target = modulesDir.appendingPathComponent("calendar.md")
        try "---\nmodule_id: calendar\n---\n# calendar\n".write(
            to: target, atomically: true, encoding: .utf8
        )

        let coreURL = identityDir.appendingPathComponent("core.md")
        try """
        ---
        name: b0t-01
        ---
        I use [calendar](../modules/calendar.md) for events.
        """.write(to: coreURL, atomically: true, encoding: .utf8)

        let store = BotStore()
        let bot = try await store.load(at: tmp)
        let links = try await store.backlinks(to: target, in: bot)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(
            links.first?.sourceFileURL.standardizedFileURL,
            coreURL.standardizedFileURL
        )
    }

    func test_backlinks_invalidatesOnFileChange() async throws {
        let coreURL = tmp.appendingPathComponent("core.md")
        let targetURL = tmp.appendingPathComponent("target.md")
        try "".write(to: targetURL, atomically: true, encoding: .utf8)
        try "links to nothing".write(to: coreURL, atomically: true, encoding: .utf8)

        let store = BotStore()
        let bot = try await store.load(at: tmp)
        var links = try await store.backlinks(to: targetURL, in: bot)
        XCTAssertEqual(links.count, 0)

        // Modify core.md to link to target.md.
        try await Task.sleep(nanoseconds: 50_000_000)
        try "see [t](target.md)".write(to: coreURL, atomically: true, encoding: .utf8)

        links = try await store.backlinks(to: targetURL, in: bot)
        XCTAssertEqual(links.count, 1)
    }
}
