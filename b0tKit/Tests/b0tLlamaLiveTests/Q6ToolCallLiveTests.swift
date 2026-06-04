import XCTest

@testable import b0tCore
@testable import b0tLlama

/// Gated (`LIVE_LLAMA=1`) end-to-end checks for the GBNF tool-call loop and the
/// chat-template render hook against the pinned build + cached SmolLM2 model.
/// The tiny test model is weak at *choosing* the right tool, so these assert the
/// grammar-enforced *format* contract (ADR-0018), not decision quality — that's
/// what the on-device Q6 harness measures across the real trio.
final class Q6ToolCallLiveTests: XCTestCase {
    func test_toolCallLoop_parsesEnvelopeNamingAKnownTool() async throws {
        let modelPath = try await LlamaModelCache.ensureModel()
        let runtime = try LlamaRuntime(modelPath: modelPath, contextLength: 2048)
        let loop = LlamaToolCallLoop(runtime: runtime)
        let env = try await loop.pickTool(
            userPrompt: "What time is it right now?",
            tools: Q6ToolCallFixtures.descriptors)
        XCTAssertNotNil(env, "the grammar should force a parseable tool-call envelope")
        if let env {
            let known = Set(Q6ToolCallFixtures.descriptors.map(\.name))
            XCTAssertTrue(known.contains(env.tool), "picked unknown tool: \(env.tool)")
        }
    }

    func test_renderChatTemplate_appliesEmbeddedTemplate() async throws {
        let modelPath = try await LlamaModelCache.ensureModel()
        let runtime = try LlamaRuntime(modelPath: modelPath, contextLength: 2048)
        let rendered = try await runtime.renderChatTemplate([
            .init(role: "system", content: "SYS"),
            .init(role: "user", content: "USR"),
        ])
        XCTAssertFalse(rendered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertTrue(rendered.contains("USR"), "rendered template should include the user content")
    }
}
