import XCTest

@testable import b0tLlama

final class LlamaRuntimeLiveTests: XCTestCase {
    func test_generatesNonEmptyText() async throws {
        let modelPath = try await LlamaModelCache.ensureModel()
        let runtime = try LlamaRuntime(modelPath: modelPath, contextLength: 2048)
        let out = try await runtime.generate(
            messages: [.init(role: "user", content: "Say the single word: hello")],
            grammar: nil,
            maxTokens: 16
        )
        XCTAssertFalse(out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertGreaterThan(runtime.contextWindow, 0)
    }
}
