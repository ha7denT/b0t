import XCTest

@testable import b0tBrain

/// Tests for the `processor.md` identity file accessor and typed frontmatter reads.
///
/// Stage C2 — `identity/processor.md` config.
final class ProcessorSectionTests: XCTestCase {
    // MARK: - Fixture helpers

    private var tmp: URL!
    private var store: BotStore!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProcessorSectionTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tmp.appendingPathComponent("identity"),
            withIntermediateDirectories: true
        )
        store = BotStore()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func writeProcessor(_ content: String) throws {
        try content.write(
            to: tmp.appendingPathComponent("identity/processor.md"),
            atomically: true, encoding: .utf8
        )
    }

    // MARK: - processor accessor on IdentitySection

    func test_processor_returnsFile() async throws {
        try writeProcessor(
            "---\nengine: foundation_models\nmodel_id: foundation_models_default\ntemperature: 0.7\n---\n\n# processor\n"
        )
        let bot = try await store.load(at: tmp)
        let file = try await bot.identity.processor
        XCTAssertNil(file.parseError, "processor.md should parse cleanly")
    }

    // MARK: - typed frontmatter: engine

    func test_engine_foundationModels() async throws {
        try writeProcessor("---\nengine: foundation_models\nmodel_id: foundation_models_default\n---\n")
        let bot = try await store.load(at: tmp)
        let file = try await bot.identity.processor
        XCTAssertEqual(file.processorEngine, "foundation_models")
    }

    func test_engine_llama() async throws {
        try writeProcessor("---\nengine: llama\nmodel_id: smollm2_360m\n---\n")
        let bot = try await store.load(at: tmp)
        let file = try await bot.identity.processor
        XCTAssertEqual(file.processorEngine, "llama")
    }

    func test_engine_absent_returnsNil() async throws {
        try writeProcessor("---\nmodel_id: foundation_models_default\n---\n")
        let bot = try await store.load(at: tmp)
        let file = try await bot.identity.processor
        XCTAssertNil(file.processorEngine)
    }

    // MARK: - typed frontmatter: modelId

    func test_modelId_returnsString() async throws {
        try writeProcessor("---\nengine: foundation_models\nmodel_id: foundation_models_default\n---\n")
        let bot = try await store.load(at: tmp)
        let file = try await bot.identity.processor
        XCTAssertEqual(file.processorModelId, "foundation_models_default")
    }

    func test_modelId_absent_returnsNil() async throws {
        try writeProcessor("---\nengine: foundation_models\n---\n")
        let bot = try await store.load(at: tmp)
        let file = try await bot.identity.processor
        XCTAssertNil(file.processorModelId)
    }
}
