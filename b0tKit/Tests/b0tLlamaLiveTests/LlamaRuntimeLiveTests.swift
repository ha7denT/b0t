import XCTest

@testable import b0tCore
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

    /// Grammar-sampler isolation check (cf. llama.cpp issue #21571). Confirms
    /// `llama_sampler_init_grammar` works against the pinned build by feeding a
    /// committed grammar to `LlamaRuntime.generate` directly and parsing the
    /// result as JSON, before `LlamaEngine` relies on it.
    func test_grammarConstrainedOutput_isParseableJSON() async throws {
        let modelPath = try await LlamaModelCache.ensureModel()
        let runtime = try LlamaRuntime(modelPath: modelPath, contextLength: 2048)
        let grammar = ConversationResponse.gbnfGrammar
        XCTAssertFalse(grammar.isEmpty, "committed grammar should be non-empty")
        let out = try await runtime.generate(
            messages: [
                .init(role: "system", content: "You are a terse assistant."),
                .init(
                    role: "user",
                    content:
                        "Greet the user in one short sentence. Respond with ONLY a JSON object. \(ConversationResponse.jsonShapeHint)"
                ),
            ],
            grammar: grammar,
            maxTokens: 256
        )
        XCTAssertFalse(out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let json = LlamaEngine.firstJSONObject(in: out)
        XCTAssertNotNil(json, "grammar output should contain a JSON object; raw: \(out.prefix(200))")
        let decoded = try JSONDecoder().decode(
            ConversationResponse.self, from: Data(json!.utf8))
        XCTAssertFalse(decoded.text.isEmpty)
    }

    func test_llamaEngine_decodesTypedConversationResponse() async throws {
        let modelPath = try await LlamaModelCache.ensureModel()
        let engine = try LlamaEngine(modelPath: modelPath, contextLength: 2048)
        let context = AssembledContext(
            systemInstructions: "You are a terse assistant.",
            userPrompt: "Greet the user in one short sentence.",
            tools: [],
            budget: .init(estimated: 0, limit: 2048, breakdown: [:], didFallBackToDigest: false),
            loadedFiles: []
        )
        let (response, records) = try await engine.generate(
            context: context, generating: ConversationResponse.self)
        XCTAssertFalse(response.text.isEmpty)
        XCTAssertTrue(records.isEmpty)  // tools off in Stage B
    }
}
