import XCTest
@testable import b0tBrain

final class BotIntegrationTests: XCTestCase {
    /// Walk up from this source file to the repo root.
    /// Layout: <repo>/b0tKit/Tests/b0tBrainTests/BotIntegrationTests.swift
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // b0tBrainTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // b0tKit/
            .deletingLastPathComponent()  // <repo>/
    }

    func test_provisionAndLoadProductionDefaultBot() async throws {
        let defaultBot = Self.repoRoot.appendingPathComponent("default-bot")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: defaultBot.path),
            "production default-bot/ missing at \(defaultBot.path)"
        )

        let documents = FileManager.default.temporaryDirectory
            .appendingPathComponent("BotIntegrationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: documents) }

        let active = try BotProvisioner.ensureDefaultBotProvisioned(
            documentsURL: documents,
            defaultBotSourceURL: defaultBot
        )

        let store = BotStore()
        let bot = try await store.load(at: active)

        // Read every named identity file. They must all exist and parse cleanly.
        let identity = bot.identity
        for file in [
            try await identity.core,
            try await identity.principles,
            try await identity.about,
            try await identity.appearance,
            try await identity.audio,
        ] {
            XCTAssertNil(
                file.parseError,
                "\(file.fileURL.lastPathComponent) failed: \(String(describing: file.parseError))"
            )
        }

        // Read every named memory file.
        for file in [
            try await bot.memory.core,
            try await bot.memory.aboutMe,
            try await bot.memory.recent,
            try await bot.memory.relationships,
        ] {
            XCTAssertNil(
                file.parseError,
                "\(file.fileURL.lastPathComponent) failed: \(String(describing: file.parseError))"
            )
        }

        // Read heartbeat files.
        for file in [
            try await bot.heartbeat.schedule,
            try await bot.heartbeat.actions,
        ] {
            XCTAssertNil(
                file.parseError,
                "\(file.fileURL.lastPathComponent) failed: \(String(describing: file.parseError))"
            )
        }

        // Enumerate all modules.
        let modules = try await bot.modules.all
        XCTAssertGreaterThan(modules.count, 0, "default-bot/modules/ ships zero modules?")
        for module in modules {
            XCTAssertNil(
                module.parseError,
                "\(module.fileURL.lastPathComponent) failed: \(String(describing: module.parseError))"
            )
            XCTAssertNotNil(module.moduleID, "\(module.fileURL.lastPathComponent) missing module_id")
        }
    }
}
