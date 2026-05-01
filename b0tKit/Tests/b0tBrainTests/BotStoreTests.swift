import XCTest

@testable import b0tBrain

final class BotStoreTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("BotStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func write(_ contents: String, named name: String) throws -> URL {
        let url = tmp.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func test_read_simpleFile() async throws {
        let url = try write("---\nk: v\n---\n# body\n", named: "a.md")
        let store = BotStore()
        let file = try await store.read(url)
        XCTAssertEqual(file.frontmatter["k"], .string("v"))
        XCTAssertEqual(file.prose, "# body\n")
    }

    func test_read_missingFile_throwsFileNotFound() async {
        let url = tmp.appendingPathComponent("missing.md")
        let store = BotStore()
        do {
            _ = try await store.read(url)
            XCTFail("expected throw")
        } catch BotFileError.fileNotFound(let failing) {
            XCTAssertEqual(failing, url)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_read_nonUTF8_throwsNotUTF8() async throws {
        let url = tmp.appendingPathComponent("bad.md")
        // 0xFE 0xFE is not valid UTF-8.
        try Data([0xFE, 0xFE]).write(to: url)
        let store = BotStore()
        do {
            _ = try await store.read(url)
            XCTFail("expected throw")
        } catch BotFileError.notUTF8(let failing) {
            XCTAssertEqual(failing, url)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_read_servesCacheWhenMtimeUnchanged() async throws {
        let url = try write("---\nk: v\n---\n", named: "a.md")

        // Warm-up: macOS APFS stores higher-precision mtime than Foundation's
        // setAttributes can write back exactly. Round-trip the mtime through
        // setAttributes once before the first read, so the on-disk mtime is
        // at the precision Foundation can preserve. Without this, the test's
        // later setAttributes call introduces sub-microsecond drift that the
        // cache's exact-equality check correctly rejects.
        let initialAttrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let initialMtime = initialAttrs[.modificationDate] as! Date
        try FileManager.default.setAttributes(
            [.modificationDate: initialMtime], ofItemAtPath: url.path
        )
        let warmedAttrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let warmedMtime = warmedAttrs[.modificationDate] as! Date

        let store = BotStore()
        let first = try await store.read(url)

        // Mutate disk to *different* content under unchanged mtime — proves
        // cache-hit by asserting the cached (original) value is returned.
        try Data("---\nk: v_NEW\n---\n".utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: warmedMtime], ofItemAtPath: url.path
        )

        let second = try await store.read(url)
        XCTAssertEqual(first, second)
        XCTAssertEqual(
            second.frontmatter["k"], .string("v"),
            "cache-hit must serve original value, not v_NEW"
        )
    }

    func test_read_reparsesWhenMtimeChanges() async throws {
        let url = try write("---\nk: v\n---\n", named: "a.md")
        let store = BotStore()
        _ = try await store.read(url)

        // Sleep at least one millisecond so APFS mtime ticks.
        try await Task.sleep(nanoseconds: 50_000_000)
        try "---\nk: v2\n---\n".write(to: url, atomically: true, encoding: .utf8)

        let updated = try await store.read(url)
        XCTAssertEqual(updated.frontmatter["k"], .string("v2"))
    }

    func test_invalidate_clearsCacheEntry() async throws {
        let url = try write("---\nk: v\n---\n", named: "a.md")
        let store = BotStore()
        _ = try await store.read(url)
        await store.invalidate(url)
        // After invalidation, even with unchanged mtime, the next read goes to disk.
        // Verify by mutating the file under the same mtime and confirming the new content is read.
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let originalMtime = attrs[.modificationDate] as! Date
        try Data("---\nk: v3\n---\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: originalMtime], ofItemAtPath: url.path)
        let reread = try await store.read(url)
        XCTAssertEqual(reread.frontmatter["k"], .string("v3"))
    }

    func test_invalidateAll_clearsEverything() async throws {
        let urlA = try write("---\nk: a\n---\n", named: "a.md")
        let urlB = try write("---\nk: b\n---\n", named: "b.md")
        let store = BotStore()
        _ = try await store.read(urlA)
        _ = try await store.read(urlB)
        await store.invalidateAll()

        // Mutate both files under unchanged mtime; reads must hit disk.
        for (url, newContent) in [(urlA, "---\nk: a2\n---\n"), (urlB, "---\nk: b2\n---\n")] {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let originalMtime = attrs[.modificationDate] as! Date
            try Data(newContent.utf8).write(to: url)
            try FileManager.default.setAttributes([.modificationDate: originalMtime], ofItemAtPath: url.path)
        }
        let aRefreshed = try await store.read(urlA)
        let bRefreshed = try await store.read(urlB)
        XCTAssertEqual(aRefreshed.frontmatter["k"], .string("a2"))
        XCTAssertEqual(bRefreshed.frontmatter["k"], .string("b2"))
    }

    // MARK: - Writes

    func test_write_persistsBytes() async throws {
        let url = try write("---\nk: v\n---\n", named: "a.md")
        let store = BotStore()
        var file = try await store.read(url)
        file = file.settingFrontmatter("k", to: .string("v2"))
        try await store.write(file)

        let onDisk = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(onDisk, "---\nk: v2\n---\n")
    }

    func test_write_updatesCache() async throws {
        let url = try write("---\nk: v\n---\n", named: "a.md")
        let store = BotStore()
        var file = try await store.read(url)
        file = file.settingFrontmatter("k", to: .string("v3"))
        try await store.write(file)
        let reread = try await store.read(url)
        XCTAssertEqual(reread.frontmatter["k"], .string("v3"))
    }

    func test_write_cleansUpTempFile() async throws {
        // After a successful write, no <name>~ sibling should remain.
        let url = try write("---\nk: v\n---\n", named: "a.md")
        let store = BotStore()
        var file = try await store.read(url)
        file = file.settingFrontmatter("k", to: .string("v4"))
        try await store.write(file)

        let siblings = try FileManager.default.contentsOfDirectory(atPath: tmp.path)
        XCTAssertFalse(siblings.contains(where: { $0.hasSuffix("~") }), "no temp leftovers")
    }

    func test_write_originalPreservedWhenTempWriteFails() async throws {
        let url = try write("---\nk: original\n---\n", named: "a.md")
        let store = BotStore()
        var file = try await store.read(url)
        file = file.settingFrontmatter("k", to: .string("changed"))

        // chmod the directory to read-only so the temp write fails.
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500], ofItemAtPath: tmp.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: tmp.path
            )
        }

        do {
            try await store.write(file)
            XCTFail("expected throw")
        } catch BotFileError.diskWriteFailed {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        // Restore perms and verify the original file survived intact.
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: tmp.path
        )
        let onDisk = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(
            onDisk, "---\nk: original\n---\n",
            "original file must survive failed write atomically")
    }
}
