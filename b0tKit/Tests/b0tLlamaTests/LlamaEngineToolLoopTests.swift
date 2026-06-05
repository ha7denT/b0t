import FoundationModels
import XCTest
import b0tBrain
import b0tCore

@testable import b0tLlama

final class LlamaEngineToolLoopTests: XCTestCase {
    final class ScriptedGenerator: LlamaGenerating, @unchecked Sendable {
        var responses: [String]
        private(set) var seenUserContents: [String] = []
        let contextWindow = 4096
        init(_ responses: [String]) { self.responses = responses }
        func generate(messages: [LlamaChatMessage], grammar: String?, maxTokens: Int) async throws -> String {
            seenUserContents.append(messages.last?.content ?? "")
            return responses.isEmpty ? "{}" : responses.removeFirst()
        }
    }

    @Generable struct NowArgs: Equatable {}
    @Generable struct NowOut: Equatable { @Guide(description: "iso time") var iso: String }
    struct TimeTool: Tool {
        let name = "time.now"
        let description = "current time"
        func call(arguments: NowArgs) async throws -> NowOut { NowOut(iso: "2026-06-05T12:00:00Z") }
    }

    private func context(tools: [any Tool], prompt: String) -> AssembledContext {
        AssembledContext(
            systemInstructions: "you are b0t", userPrompt: prompt, tools: tools,
            toolsRequirePermission: false,
            budget: TokenBudget(estimated: 0, limit: 4096, breakdown: [:], didFallBackToDigest: false),
            loadedFiles: [])
    }

    func test_toolPicked_executesAndFeedsResultToAnswer() async throws {
        let gen = ScriptedGenerator([
            #"{"tool":"time.now","arguments":{}}"#,
            #"{"text":"it is noon","mood":null,"memoryObservations":[]}"#,
        ])
        let engine = LlamaEngine(runtimeReusing: gen, supportsToolLoop: true)
        let (resp, records): (ConversationResponse, [ToolCallRecord]) =
            try await engine.generate(
                context: context(tools: [TimeTool()], prompt: "what time is it?"),
                generating: ConversationResponse.self)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.toolName, "time.now")
        XCTAssertTrue(records.first?.outputSummary.contains("2026-06-05") ?? false)
        XCTAssertTrue(gen.seenUserContents.last?.contains("2026-06-05") ?? false)
        XCTAssertEqual(resp.text, "it is noon")
    }

    func test_noneChoice_singlePassNoRecords() async throws {
        let gen = ScriptedGenerator([
            #"{"tool":"none","arguments":{}}"#,
            #"{"text":"hello","mood":null,"memoryObservations":[]}"#,
        ])
        let engine = LlamaEngine(runtimeReusing: gen, supportsToolLoop: true)
        let (resp, records): (ConversationResponse, [ToolCallRecord]) =
            try await engine.generate(
                context: context(tools: [TimeTool()], prompt: "hi"),
                generating: ConversationResponse.self)
        XCTAssertEqual(records.count, 0)
        XCTAssertEqual(resp.text, "hello")
    }

    func test_supportsToolLoopFalse_skipsGate() async throws {
        let gen = ScriptedGenerator([
            #"{"text":"hi","mood":null,"memoryObservations":[]}"#
        ])
        let engine = LlamaEngine(runtimeReusing: gen, supportsToolLoop: false)
        let (_, records): (ConversationResponse, [ToolCallRecord]) =
            try await engine.generate(
                context: context(tools: [TimeTool()], prompt: "hi"),
                generating: ConversationResponse.self)
        XCTAssertEqual(records.count, 0)
        XCTAssertEqual(gen.seenUserContents.count, 1)
    }
}
