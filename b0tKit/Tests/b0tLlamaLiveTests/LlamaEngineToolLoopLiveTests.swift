import FoundationModels
import XCTest
import b0tBrain

@testable import b0tCore
@testable import b0tLlama

/// Gated (`LIVE_LLAMA=1`) end-to-end test for the two-pass tool-call loop in
/// `LlamaEngine` against the cached SmolLM2 model.
///
/// The SmolLM2-360M model is weak at *choosing* tools, so the assertions are
/// tolerant: we assert the loop ran end-to-end without throwing and produced a
/// non-empty answer text. A tool record is asserted as the goal (the grammar
/// should produce a valid envelope) but the test passes even if the model
/// picks "none" — because the important contract is that the engine handles
/// both branches without error.
final class LlamaEngineToolLoopLiveTests: XCTestCase {
    // MARK: — Local tool (mirrors LlamaEngineToolLoopTests.TimeTool)

    @Generable struct NowArgs: Equatable {}
    @Generable struct NowOut: Equatable {
        @Guide(description: "ISO-8601 timestamp") var iso: String
    }
    struct TimeTool: Tool {
        let name = "time.now"
        let description = "Returns the current time as an ISO-8601 string."
        func call(arguments: NowArgs) async throws -> NowOut {
            NowOut(iso: "2026-06-05T12:00:00Z")
        }
    }

    // MARK: — Helpers

    private func makeContext(prompt: String) -> AssembledContext {
        AssembledContext(
            systemInstructions: "You are b0t, a helpful local AI assistant.",
            userPrompt: prompt,
            tools: [TimeTool()],
            toolsRequirePermission: false,
            budget: TokenBudget(
                estimated: 0, limit: 2048, breakdown: [:], didFallBackToDigest: false),
            loadedFiles: []
        )
    }

    // MARK: — Live test

    func test_toolLoop_runsEndToEndWithoutThrowing() async throws {
        let modelPath = try await LlamaModelCache.ensureModel()
        let runtime = try LlamaRuntime(modelPath: modelPath, contextLength: 2048)
        let engine = LlamaEngine(runtimeReusing: runtime, supportsToolLoop: true)

        let ctx = makeContext(prompt: "what time is it?")
        let (response, records): (ConversationResponse, [ToolCallRecord]) =
            try await engine.generate(context: ctx, generating: ConversationResponse.self)

        // Floor assertion: the loop must complete and return non-empty answer text.
        XCTAssertFalse(
            response.text.isEmpty,
            "engine should produce a non-empty answer; got empty text")

        // Goal assertion: the model picked and executed the tool.
        // SmolLM2-360M may not reliably call tools, so we log the outcome but do
        // not fail if it chose "none".
        if records.isEmpty {
            XCTAssertTrue(
                true,
                "model chose 'none' — acceptable for a 360M model; loop still ran end-to-end")
        } else {
            let knownTools = Set(ctx.tools.map(\.name))
            for record in records {
                XCTAssertTrue(
                    knownTools.contains(record.toolName),
                    "record references unknown tool '\(record.toolName)'")
            }
            XCTAssertFalse(
                records.first?.outputSummary.isEmpty ?? true,
                "tool outputSummary should be non-empty")
        }
    }
}
