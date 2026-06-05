import XCTest
import b0tBrain
import b0tCore

@testable import b0tLlama

final class EngineHostTests: XCTestCase {
    /// A stub engine that records its identity via contextWindow.
    struct StubEngine: InferenceEngine {
        let window: Int
        var contextWindow: Int { window }
        func generate<Output: StructuredOutput>(
            context: AssembledContext, generating outputType: Output.Type
        ) async throws -> (Output, [ToolCallRecord]) {
            throw InferenceEngineError.sessionFailed(underlyingDescription: "stub")
        }
    }

    func test_initialEngine_isForwarded() {
        let host = EngineHost(
            initialEngine: StubEngine(window: 4096), initialModelId: "foundation_models_default",
            loader: { _ in nil })
        XCTAssertEqual(host.contextWindow, 4096)
        XCTAssertEqual(host.activeModelId, "foundation_models_default")
    }

    func test_selectModel_loadsAndSwaps_whenLoaderReturnsEngine() async {
        let host = EngineHost(
            initialEngine: StubEngine(window: 4096), initialModelId: "foundation_models_default",
            loader: { id in id == "qwen3-1.7b" ? (StubEngine(window: 32768), 32768) : nil })
        let outcome = await host.selectModel(id: "qwen3-1.7b")
        XCTAssertEqual(outcome, .active(modelId: "qwen3-1.7b"))
        XCTAssertEqual(host.contextWindow, 32768)
        XCTAssertEqual(host.activeModelId, "qwen3-1.7b")
    }

    func test_selectModel_missing_keepsCurrentEngine() async {
        let host = EngineHost(
            initialEngine: StubEngine(window: 4096), initialModelId: "foundation_models_default",
            loader: { _ in nil })
        let outcome = await host.selectModel(id: "llama-3.2-1b")
        XCTAssertEqual(outcome, .missing(modelId: "llama-3.2-1b"))
        XCTAssertEqual(host.contextWindow, 4096)
        XCTAssertEqual(host.activeModelId, "foundation_models_default")
    }

    func test_generate_forwardsToCurrentEngine() async {
        let host = EngineHost(
            initialEngine: StubEngine(window: 4096), initialModelId: "x", loader: { _ in nil })
        let context = AssembledContext(
            systemInstructions: "s", userPrompt: "u", tools: [], toolsRequirePermission: false,
            budget: TokenBudget(estimated: 0, limit: 4096, breakdown: [:], didFallBackToDigest: false),
            loadedFiles: [])
        do {
            _ = try await host.generate(context: context, generating: ConversationResponse.self)
            XCTFail("expected the stub engine's error to propagate")
        } catch let InferenceEngineError.sessionFailed(desc) {
            XCTAssertEqual(desc, "stub")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
