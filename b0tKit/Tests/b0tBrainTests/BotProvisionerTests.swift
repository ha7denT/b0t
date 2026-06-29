import XCTest
@testable import b0tBrain

final class BotProvisionerTests: XCTestCase {
    private var documents: URL!
    private var bundleStubRoot: URL!

    override func setUpWithError() throws {
        let id = UUID().uuidString
        documents = FileManager.default.temporaryDirectory
            .appendingPathComponent("Documents-\(id)")
        bundleStubRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("Bundle-\(id)")

        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        // Build a minimal default-bot/ inside the stub bundle.
        let defaultBot = bundleStubRoot.appendingPathComponent("default-bot")
        try FileManager.default.createDirectory(
            at: defaultBot.appendingPathComponent("identity"),
            withIntermediateDirectories: true)
        try "---\nname: b0t-01\n---\n".write(
            to: defaultBot.appendingPathComponent("identity/core.md"),
            atomically: true, encoding: .utf8
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: documents)
        try? FileManager.default.removeItem(at: bundleStubRoot)
    }

    func test_freshDocumentsDirectory_provisionsB01() throws {
        let active = try BotProvisioner.ensureDefaultBotProvisioned(
            documentsURL: documents,
            defaultBotSourceURL: bundleStubRoot.appendingPathComponent("default-bot")
        )
        XCTAssertEqual(active.lastPathComponent, "b0t-01")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: active.appendingPathComponent("identity/core.md").path))
        let activePtr = try String(
            contentsOf: documents.appendingPathComponent("b0ts/_active"),
            encoding: .utf8
        )
        XCTAssertEqual(activePtr, "b0t-01\n")
    }

    func test_secondCall_isIdempotent_doesNotOverwrite() throws {
        let first = try BotProvisioner.ensureDefaultBotProvisioned(
            documentsURL: documents,
            defaultBotSourceURL: bundleStubRoot.appendingPathComponent("default-bot")
        )
        // Mutate the provisioned file. A second provision must NOT clobber it.
        let core = first.appendingPathComponent("identity/core.md")
        try "user-edited content\n".write(to: core, atomically: true, encoding: .utf8)

        let second = try BotProvisioner.ensureDefaultBotProvisioned(
            documentsURL: documents,
            defaultBotSourceURL: bundleStubRoot.appendingPathComponent("default-bot")
        )
        XCTAssertEqual(first, second)
        let now = try String(contentsOf: core, encoding: .utf8)
        XCTAssertEqual(now, "user-edited content\n")
    }

    func test_activePtrPointsToMissingDir_fallsBackToFreshProvision() throws {
        // Create _active pointing at a non-existent dir.
        let b0ts = documents.appendingPathComponent("b0ts")
        try FileManager.default.createDirectory(at: b0ts, withIntermediateDirectories: true)
        try "phantom\n".write(
            to: b0ts.appendingPathComponent("_active"),
            atomically: true, encoding: .utf8
        )

        let active = try BotProvisioner.ensureDefaultBotProvisioned(
            documentsURL: documents,
            defaultBotSourceURL: bundleStubRoot.appendingPathComponent("default-bot")
        )
        XCTAssertEqual(active.lastPathComponent, "b0t-01")
    }

    func test_existingInstall_gainsNewlyBundledFile() throws {
        let source = bundleStubRoot.appendingPathComponent("default-bot")
        // First provision creates b0t-01 (+ _active) from the stub bundle.
        _ = try BotProvisioner.ensureDefaultBotProvisioned(
            documentsURL: documents, defaultBotSourceURL: source)

        // Simulate an app update that adds a new bundled module in a NEW subdir.
        let newModule = source.appendingPathComponent("modules/weather.md")
        try FileManager.default.createDirectory(
            at: newModule.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "---\nmodule_id: weather\n---\n".write(
            to: newModule, atomically: true, encoding: .utf8)

        // Second provision (active bot exists) must sync the new file in.
        let active = try BotProvisioner.ensureDefaultBotProvisioned(
            documentsURL: documents, defaultBotSourceURL: source)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: active.appendingPathComponent("modules/weather.md").path),
            "newly-bundled module should be synced into the existing install")
    }

    func test_sync_doesNotOverwriteUserEditedFile() throws {
        let source = bundleStubRoot.appendingPathComponent("default-bot")
        let active = try BotProvisioner.ensureDefaultBotProvisioned(
            documentsURL: documents, defaultBotSourceURL: source)
        // User edits an existing file.
        let core = active.appendingPathComponent("identity/core.md")
        try "user-edited\n".write(to: core, atomically: true, encoding: .utf8)
        // Add a new bundled file too, so the sync pass definitely runs.
        let newFile = source.appendingPathComponent("modules/weather.md")
        try FileManager.default.createDirectory(
            at: newFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "x\n".write(to: newFile, atomically: true, encoding: .utf8)

        _ = try BotProvisioner.ensureDefaultBotProvisioned(
            documentsURL: documents, defaultBotSourceURL: source)

        XCTAssertEqual(try String(contentsOf: core, encoding: .utf8), "user-edited\n")
    }
}
