# Llama Tool-Call Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a downloaded (llama) model complete a tool-assisted turn — pick one tool, execute it via the existing b0tModules tools, feed the result back, and produce the final answer — matching what Foundation Models does natively.

**Architecture:** Approach A (spec §2): a two-pass flow inside `LlamaEngine.generate` — pass 1 GBNF tool-gate (`{tool|none, arguments}`), execute via a b0tCore `ToolExecutor` (Swift existential opening, no per-tool code), inject the result, pass 2 reuses the existing GBNF structured-output path for the final answer. Gated per-model by a curated `supportsToolLoop`.

**Tech Stack:** Swift 6 (strict concurrency), FoundationModels (`Tool`/`GeneratedContent`/`Generable`), the pure-C `b0tLlama` (`LlamaRuntime`, GBNF), swift-testing/XCTest via `swift test`.

**Spec:** `docs/specs/phase-2-llama-tool-call-loop.md`. **Relates to:** [ADR-0018](../decisions/0018-llama-tool-calling-via-gbnf-pure-c.md).

---

## File structure

**Create**
- `b0tKit/Sources/b0tCore/Model/ToolExecutor.swift` — execute an `any Tool` from JSON args (existential opening); `ToolRunResult`.
- `b0tKit/Sources/b0tLlama/LlamaGenerating.swift` — one-method generation seam; `LlamaRuntime` conforms.
- `b0tKit/Tests/b0tCoreTests/ToolExecutorTests.swift`
- `b0tKit/Tests/b0tLlamaTests/LlamaToolGateTests.swift`
- `b0tKit/Tests/b0tLlamaTests/LlamaEngineToolLoopTests.swift`

**Modify**
- `b0tKit/Sources/b0tLlama/ToolCalling.swift` — gate helpers (`"none"` reserved name).
- `b0tKit/Sources/b0tLlama/LlamaEngine.swift` — store `any LlamaGenerating`; factor `singlePassStructured`; add the two-pass `generate` + `supportsToolLoop`.
- `b0tKit/Sources/b0tBrain/InferenceModelCatalogue.swift` — `supportsToolLoop` on `InferenceModelEntry` (curated).
- `b0tKit/Sources/b0tLlama/EngineHost.swift` — pass `entry.supportsToolLoop` into `LlamaEngine`.

---

## Slice 1 — Execution bridge (the risk-first spike)

### Task 1: `ToolExecutor` — execute `any Tool` from JSON

This is the load-bearing technical risk (spec §4). Build and prove it FIRST. If the existential-opening + `Arguments(GeneratedContent)` path does not compile or behave, STOP and report — the fallback (a per-tool `callJSON` protocol) changes later tasks.

**Files:**
- Create: `b0tKit/Sources/b0tCore/Model/ToolExecutor.swift`
- Test: `b0tKit/Tests/b0tCoreTests/ToolExecutorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import FoundationModels
@testable import b0tCore

final class ToolExecutorTests: XCTestCase {
    @Generable struct EchoArgs: Equatable {
        @Guide(description: "text to echo") var text: String
    }
    @Generable struct EchoOut: Equatable {
        @Guide(description: "the echoed text") var echoed: String
    }
    struct EchoTool: Tool {
        let name = "echo"
        let description = "Echoes its text argument."
        func call(arguments: EchoArgs) async throws -> EchoOut { EchoOut(echoed: arguments.text) }
    }

    func test_execute_buildsArgsCallsToolAndStringifiesOutput() async throws {
        let tools: [any Tool] = [EchoTool()]
        let tool = try XCTUnwrap(ToolExecutor.tool(named: "echo", in: tools))
        let result = try await ToolExecutor.execute(tool: tool, argumentsJSON: #"{"text":"hi there"}"#)
        XCTAssertTrue(result.outputSummary.contains("hi there"))
        XCTAssertTrue(result.argumentsSummary.contains("hi there"))
    }

    func test_toolNamed_returnsNilForUnknown() {
        XCTAssertNil(ToolExecutor.tool(named: "nope", in: [EchoTool()]))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd b0tKit && swift test --filter ToolExecutorTests`
Expected: FAIL — `cannot find 'ToolExecutor' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import FoundationModels

/// Result of running a tool: human/model-readable summaries for the answer pass
/// and the `ToolCallRecord`.
public struct ToolRunResult: Sendable, Equatable {
    public let outputSummary: String
    public let argumentsSummary: String
    public init(outputSummary: String, argumentsSummary: String) {
        self.outputSummary = outputSummary
        self.argumentsSummary = argumentsSummary
    }
}

/// Executes an `any Tool` (Foundation Models `Tool`) from JSON arguments, for the
/// llama tool-call loop (spec §4). Uses Swift implicit existential opening to
/// recover the concrete tool type, build its `@Generable` `Arguments` from a
/// `GeneratedContent(json:)`, call it, and stringify the output. No per-tool code.
public enum ToolExecutor {
    public static func tool(named name: String, in tools: [any Tool]) -> (any Tool)? {
        tools.first { $0.name == name }
    }

    public static func execute(tool: any Tool, argumentsJSON: String) async throws -> ToolRunResult {
        try await run(tool, argumentsJSON: argumentsJSON)
    }

    /// Generic over the opened existential `T`, so `T.Arguments` is concrete.
    private static func run<T: Tool>(_ tool: T, argumentsJSON: String) async throws -> ToolRunResult {
        let content = try GeneratedContent(json: argumentsJSON)
        let args = try T.Arguments(content)
        let output = try await tool.call(arguments: args)
        let outSummary = stringify(output)
        return ToolRunResult(outputSummary: outSummary, argumentsSummary: argumentsJSON)
    }

    /// Best-effort string form of a tool Output: prefer its GeneratedContent JSON
    /// (our tool Outputs are `@Generable`), else a described fallback.
    private static func stringify(_ value: Any) -> String {
        if let convertible = value as? any ConvertibleToGeneratedContent {
            return convertible.generatedContent.jsonString
        }
        return String(describing: value)
    }
}
```

IMPORTANT (validate against the real SDK — this is the spike): confirm in Xcode 26's FoundationModels that (a) `GeneratedContent(json:)` is a throwing initializer taking a JSON string; (b) a `@Generable` type conforms to `ConvertibleFromGeneratedContent` with `init(_ : GeneratedContent) throws` so `T.Arguments(content)` compiles; (c) `Tool.Output` can be cast to `any ConvertibleToGeneratedContent` and `GeneratedContent` has `jsonString`. If any differ, adapt minimally (e.g. the exact `GeneratedContent` init label, or use `output.generatedContent` if `Output: Generable` is available via the protocol). If the approach is fundamentally unavailable, STOP and report DONE_WITH_CONCERNS describing what the SDK actually exposes — we switch to the per-tool `callJSON` fallback.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd b0tKit && swift test --filter ToolExecutorTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tCore/Model/ToolExecutor.swift b0tKit/Tests/b0tCoreTests/ToolExecutorTests.swift
git commit -m "feat(b0tCore): ToolExecutor — run any Tool from JSON via existential opening (llama tool loop)"
```

---

## Slice 2 — Generation seam + tool gate (b0tLlama)

### Task 2: `LlamaGenerating` seam + conform `LlamaRuntime`

Abstract the one `generate` call so `LlamaEngine`'s two-pass logic is unit-testable with a fake generator.

**Files:**
- Create: `b0tKit/Sources/b0tLlama/LlamaGenerating.swift`
- Modify: `b0tKit/Sources/b0tLlama/LlamaRuntime.swift` (add conformance only)
- Test: covered via Task 5 (the fake conformer lives in the test target).

- [ ] **Step 1: Inspect the real `LlamaRuntime` shape**

Read `b0tKit/Sources/b0tLlama/LlamaRuntime.swift`. Determine: is it an `actor` or a `class`? (The `isolated deinit` hint suggests an actor.) How is `contextWindow` exposed (sync? nonisolated?) — `LlamaEngine.contextWindow` reads `runtime.contextWindow` synchronously today, so it is reachable without `await`. The protocol must match that reality.

- [ ] **Step 2: Write the protocol**

```swift
import Foundation

/// The single generation primitive `LlamaEngine` needs, abstracted so the
/// two-pass tool-call loop is testable without loading a real model.
/// `LlamaRuntime` is the production conformer.
public protocol LlamaGenerating: Sendable {
    var contextWindow: Int { get }
    func generate(
        messages: [LlamaChatMessage], grammar: String?, maxTokens: Int
    ) async throws -> String
}
```

If `LlamaRuntime` is an `actor` and its `contextWindow` is `nonisolated` (it must be, since `LlamaEngine.contextWindow` reads it synchronously), this protocol matches: actors satisfy `async` requirements, and a `nonisolated var` satisfies the sync `contextWindow` getter. If `contextWindow` is NOT currently nonisolated, make it `nonisolated` in `LlamaRuntime` (it returns a stored `Int`, safe to read).

- [ ] **Step 3: Conform `LlamaRuntime`**

In `LlamaRuntime.swift`, add the conformance. It already has both members, so this should be a no-op declaration:
```swift
extension LlamaRuntime: LlamaGenerating {}
```
(If the signatures don't line up exactly — e.g. `contextWindow` isolation — fix that on `LlamaRuntime` so the conformance holds.)

- [ ] **Step 4: Verify it builds**

Run: `cd b0tKit && swift build`
Expected: clean. Run `cd b0tKit && swift test --filter b0tLlamaTests` → existing tests still pass.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tLlama/LlamaGenerating.swift b0tKit/Sources/b0tLlama/LlamaRuntime.swift
git commit -m "feat(b0tLlama): LlamaGenerating seam; LlamaRuntime conforms (testability for tool loop)"
```

---

### Task 3: Tool-gate envelope + grammar (`"none"` reserved name)

Add a pure helper that builds the gate grammar (tool names + `"none"`) and the gate system prompt, reusing the existing builder. `ToolCallEnvelope.parse` already exists on `LlamaToolCallLoop`; the gate adds the `"none"` semantics + the argument-JSON serialisation helper.

**Files:**
- Modify: `b0tKit/Sources/b0tLlama/ToolCalling.swift`
- Test: `b0tKit/Tests/b0tLlamaTests/LlamaToolGateTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import b0tLlama

final class LlamaToolGateTests: XCTestCase {
    let tools: [ToolDescriptor] = [
        .init(name: "time.now", description: "current time"),
        .init(name: "calendar.upcoming_events", description: "upcoming events"),
    ]

    func test_gateGrammar_includesNoneAndToolNames() {
        let g = ToolGate.grammar(for: tools)
        XCTAssertTrue(g.contains("time.now"))
        XCTAssertTrue(g.contains("calendar.upcoming_events"))
        XCTAssertTrue(g.contains("none"))
    }

    func test_gatePrompt_listsToolsAndAllowsNone() {
        let p = ToolGate.systemPrompt(for: tools)
        XCTAssertTrue(p.contains("time.now"))
        XCTAssertTrue(p.contains("none"))  // model is told it may decline
    }

    func test_argumentsJSONString_serialisesEnvelopeArguments() throws {
        let env = ToolCallEnvelope(tool: "time.now", arguments: .object([:]))
        XCTAssertEqual(ToolGate.argumentsJSON(env), "{}")
    }

    func test_isNone_detectsTheReservedName() {
        XCTAssertTrue(ToolGate.isNone(ToolCallEnvelope(tool: "none", arguments: .object([:]))))
        XCTAssertFalse(ToolGate.isNone(ToolCallEnvelope(tool: "time.now", arguments: .object([:]))))
    }
}
```

NOTE: confirm `JSONValue`'s case for an empty object is `.object([:])` (read the `JSONValue` definition — grep `enum JSONValue`). If the case name/shape differs (e.g. `.dictionary`), adapt the test + helper to the real API. `JSONValue` is `Codable`, so `argumentsJSON` can encode it regardless of case names.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd b0tKit && swift test --filter LlamaToolGateTests`
Expected: FAIL — `cannot find 'ToolGate' in scope`.

- [ ] **Step 3: Write minimal implementation**

Append to `ToolCalling.swift`:

```swift
/// Builds the one-shot "tool gate": the grammar + prompt that let a model pick
/// exactly one tool OR decline with the reserved name "none" (spec §5). Pure.
public enum ToolGate {
    public static let noneName = "none"

    public static func grammar(for tools: [ToolDescriptor]) -> String {
        ToolCallGrammarBuilder.grammar(toolNames: tools.map(\.name) + [noneName])
    }

    public static func systemPrompt(for tools: [ToolDescriptor]) -> String {
        let list = tools.map { "- \($0.name): \($0.description)" }.joined(separator: "\n")
        return """
            Decide whether a tool is needed to answer the user. Available tools:
            \(list)

            Respond with ONLY a JSON object: {"tool": "<a tool name above>", "arguments": { ... }} \
            to call a tool, or {"tool": "none", "arguments": {}} if no tool is needed. \
            Choose at most one tool.
            """
    }

    public static func isNone(_ envelope: ToolCallEnvelope) -> Bool {
        envelope.tool == noneName
    }

    /// Serialises the envelope's arguments back to a JSON string for `ToolExecutor`.
    public static func argumentsJSON(_ envelope: ToolCallEnvelope) -> String {
        guard let data = try? JSONEncoder().encode(envelope.arguments),
            let s = String(data: data, encoding: .utf8)
        else { return "{}" }
        return s
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd b0tKit && swift test --filter LlamaToolGateTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tLlama/ToolCalling.swift b0tKit/Tests/b0tLlamaTests/LlamaToolGateTests.swift
git commit -m "feat(b0tLlama): ToolGate — grammar/prompt/none-detection for the tool-call gate"
```

---

## Slice 3 — Two-pass `LlamaEngine`

### Task 4: Refactor `LlamaEngine` onto the seam (no behaviour change)

Switch the stored runtime to `any LlamaGenerating`, add a `supportsToolLoop` stored flag (default keeps current behaviour), and factor the current body into a private `singlePassStructured`. No functional change yet — existing tests must pass unchanged.

**Files:**
- Modify: `b0tKit/Sources/b0tLlama/LlamaEngine.swift`

- [ ] **Step 1: Refactor (read the full current file first)**

```swift
public struct LlamaEngine: InferenceEngine {
    private let runtime: any LlamaGenerating
    private let supportsToolLoop: Bool

    public var contextWindow: Int { runtime.contextWindow }

    public init(modelPath: URL, contextLength: Int, supportsToolLoop: Bool = false) throws {
        self.runtime = try LlamaRuntime(modelPath: modelPath, contextLength: contextLength)
        self.supportsToolLoop = supportsToolLoop
    }

    public init(runtimeReusing runtime: any LlamaGenerating, supportsToolLoop: Bool = false) {
        self.runtime = runtime
        self.supportsToolLoop = supportsToolLoop
    }

    public func generate<Output: StructuredOutput>(
        context: AssembledContext, generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord]) {
        // Tool loop arrives in Task 5; for now, structured single-pass.
        let output = try await singlePassStructured(context: context, generating: outputType)
        return (output, [])
    }

    /// The final-answer / no-tools path: describe the shape in-prompt, generate
    /// under the type's GBNF grammar, decode JSON.
    private func singlePassStructured<Output: StructuredOutput>(
        context: AssembledContext, generating outputType: Output.Type
    ) async throws -> Output {
        let userContent = """
            \(context.userPrompt)

            Respond with ONLY a JSON object and nothing else. \(Output.jsonShapeHint)
            """
        let messages = [
            LlamaChatMessage(role: "system", content: context.systemInstructions),
            LlamaChatMessage(role: "user", content: userContent),
        ]
        let raw = try await runtime.generate(
            messages: messages,
            grammar: Output.gbnfGrammar.isEmpty ? nil : Output.gbnfGrammar,
            maxTokens: 512)
        guard let data = Self.firstJSONObject(in: raw)?.data(using: .utf8) else {
            throw InferenceEngineError.malformedGenerableOutput(
                underlyingDescription: "no JSON object in llama output: \(raw.prefix(200))")
        }
        do {
            return try JSONDecoder().decode(Output.self, from: data)
        } catch {
            throw InferenceEngineError.malformedGenerableOutput(
                underlyingDescription: String(describing: error))
        }
    }

    static func firstJSONObject(in text: String) -> String? {
        // ... keep the existing implementation unchanged ...
    }
}
```
Keep `firstJSONObject` exactly as-is. NOTE: the `init(runtimeReusing:)` parameter type widens from `LlamaRuntime` to `any LlamaGenerating` — `LlamaRuntime` still satisfies it, so existing callers (`EngineHost.makeProductionLoader`, the Q6 harness) keep compiling. Confirm with a grep of `LlamaEngine(` call sites.

- [ ] **Step 2: Verify no regression**

Run: `cd b0tKit && swift test --filter b0tLlamaTests`
Expected: PASS (existing LlamaEngine + loader + gate tests). Run `cd b0tKit && swift build` clean.

- [ ] **Step 3: Commit**

```bash
git add b0tKit/Sources/b0tLlama/LlamaEngine.swift
git commit -m "refactor(b0tLlama): LlamaEngine on LlamaGenerating seam + singlePassStructured (no behaviour change)"
```

---

### Task 5: Two-pass `generate` — gate → execute → answer

**Files:**
- Modify: `b0tKit/Sources/b0tLlama/LlamaEngine.swift`
- Test: `b0tKit/Tests/b0tLlamaTests/LlamaEngineToolLoopTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import FoundationModels
import b0tBrain
import b0tCore
@testable import b0tLlama

final class LlamaEngineToolLoopTests: XCTestCase {
    // A scripted generator: returns queued responses in order, recording prompts.
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

    // A tool the loop can execute.
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
            #"{"tool":"time.now","arguments":{}}"#,                 // pass 1 — gate
            #"{"text":"it is noon","mood":"neutral","memoryObservations":[]}"#,  // pass 2 — answer
        ])
        let engine = LlamaEngine(runtimeReusing: gen, supportsToolLoop: true)
        let (resp, records): (ConversationResponse, [ToolCallRecord]) =
            try await engine.generate(
                context: context(tools: [TimeTool()], prompt: "what time is it?"),
                generating: ConversationResponse.self)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.toolName, "time.now")
        XCTAssertTrue(records.first?.outputSummary.contains("2026-06-05") ?? false)
        // pass-2 prompt carried the tool result
        XCTAssertTrue(gen.seenUserContents.last?.contains("2026-06-05") ?? false)
        XCTAssertEqual(resp.text, "it is noon")
    }

    func test_noneChoice_singlePassNoRecords() async throws {
        let gen = ScriptedGenerator([
            #"{"tool":"none","arguments":{}}"#,
            #"{"text":"hello","mood":"neutral","memoryObservations":[]}"#,
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
            #"{"text":"hi","mood":"neutral","memoryObservations":[]}"#,  // only the answer pass
        ])
        let engine = LlamaEngine(runtimeReusing: gen, supportsToolLoop: false)
        let (_, records): (ConversationResponse, [ToolCallRecord]) =
            try await engine.generate(
                context: context(tools: [TimeTool()], prompt: "hi"),
                generating: ConversationResponse.self)
        XCTAssertEqual(records.count, 0)
        XCTAssertEqual(gen.seenUserContents.count, 1)  // no gate call
    }
}
```

NOTE: verify `ConversationResponse`'s real JSON shape + `jsonShapeHint`/`gbnfGrammar` so the canned pass-2 JSON decodes (read `b0tCore/Decisions/ConversationResponse.swift`; the convenience `ConversationResponse(text:)` confirms the fields). Adjust the canned JSON to the actual required keys. Confirm `AssembledContext`'s initializer labels (Task 3 of Stage D used the same).

- [ ] **Step 2: Run test to verify it fails**

Run: `cd b0tKit && swift test --filter LlamaEngineToolLoopTests`
Expected: FAIL (the current `generate` ignores tools → no records / wrong call count).

- [ ] **Step 3: Implement the two-pass `generate`**

Replace `generate` in `LlamaEngine.swift`:

```swift
    public func generate<Output: StructuredOutput>(
        context: AssembledContext, generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord]) {
        guard supportsToolLoop, !context.tools.isEmpty else {
            let output = try await singlePassStructured(context: context, generating: outputType)
            return (output, [])
        }

        // Pass 1 — tool gate.
        let descriptors = context.tools.map {
            ToolDescriptor(name: $0.name, description: $0.description)
        }
        let gateMessages = [
            LlamaChatMessage(role: "system", content: ToolGate.systemPrompt(for: descriptors)),
            LlamaChatMessage(role: "user", content: context.userPrompt),
        ]
        let gateRaw = try await runtime.generate(
            messages: gateMessages, grammar: ToolGate.grammar(for: descriptors), maxTokens: 256)

        var records: [ToolCallRecord] = []
        var answerContext = context

        if let env = LlamaToolCallLoop.parse(gateRaw), !ToolGate.isNone(env),
            let tool = ToolExecutor.tool(named: env.tool, in: context.tools)
        {
            let argsJSON = ToolGate.argumentsJSON(env)
            do {
                let result = try await ToolExecutor.execute(tool: tool, argumentsJSON: argsJSON)
                records.append(ToolCallRecord(
                    toolName: env.tool, argumentsSummary: result.argumentsSummary,
                    outputSummary: result.outputSummary, timestamp: Date()))
                answerContext = Self.injectingToolResult(
                    context, tool: env.tool, summary: result.outputSummary)
            } catch {
                let note = "(tool error: \(error))"
                records.append(ToolCallRecord(
                    toolName: env.tool, argumentsSummary: argsJSON,
                    outputSummary: "errored", timestamp: Date()))
                answerContext = Self.injectingToolResult(context, tool: env.tool, summary: note)
            }
        }
        // unparseable / unknown tool / "none" → answerContext unchanged, records empty

        // Pass 2 — final structured answer.
        let output = try await singlePassStructured(context: answerContext, generating: outputType)
        return (output, records)
    }

    /// Returns a copy of `context` with the tool result appended to the user
    /// prompt, so the answer pass can ground its reply on it.
    private static func injectingToolResult(
        _ context: AssembledContext, tool: String, summary: String
    ) -> AssembledContext {
        AssembledContext(
            systemInstructions: context.systemInstructions,
            userPrompt: context.userPrompt + "\n\ntool \(tool) result: \(summary)",
            tools: context.tools,
            toolsRequirePermission: context.toolsRequirePermission,
            budget: context.budget,
            loadedFiles: context.loadedFiles)
    }
```

NOTE: confirm `AssembledContext`'s public initializer parameter list matches the `injectingToolResult` call (read `b0tCore/Context/AssembledContext.swift`). If it has more/other fields, copy them through faithfully. `Date()` is fine in app/library code (the `Date.now` ban is only for workflow scripts).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd b0tKit && swift test --filter LlamaEngineToolLoopTests`
Expected: PASS (3 tests).
Run: `cd b0tKit && swift test --filter b0tLlamaTests`
Expected: PASS — no regressions.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tLlama/LlamaEngine.swift b0tKit/Tests/b0tLlamaTests/LlamaEngineToolLoopTests.swift
git commit -m "feat(b0tLlama): two-pass tool-call loop in LlamaEngine.generate (gate→execute→answer)"
```

---

## Slice 4 — Catalogue gate + integration

### Task 6: `supportsToolLoop` on the catalogue + thread through `EngineHost`

**Files:**
- Modify: `b0tKit/Sources/b0tBrain/InferenceModelCatalogue.swift`
- Modify: `b0tKit/Sources/b0tLlama/EngineHost.swift`
- Test: `b0tKit/Tests/b0tBrainTests/InferenceModelCatalogueTests.swift` (extend)

- [ ] **Step 1: Write the failing test (extend the catalogue tests)**

```swift
    func test_supportsToolLoop_curatedPerEntry() {
        XCTAssertTrue(InferenceModelCatalogue.qwen3.supportsToolLoop)
        XCTAssertTrue(InferenceModelCatalogue.llama32.supportsToolLoop)
        XCTAssertTrue(InferenceModelCatalogue.qwen25.supportsToolLoop)
        XCTAssertFalse(InferenceModelCatalogue.smolLM2Test.supportsToolLoop)
    }
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd b0tKit && swift test --filter InferenceModelCatalogueTests`
Expected: FAIL — `value of type 'InferenceModelEntry' has no member 'supportsToolLoop'`.

- [ ] **Step 3: Add the field + set it**

In `InferenceModelEntry`: add `public let supportsToolLoop: Bool` and add `supportsToolLoop: Bool = true` to the memberwise `init` (last parameter, defaulted so other constructions are unaffected), assigning it. Then set per entry:
- `qwen3`, `llama32`, `qwen25`: pass `supportsToolLoop: true` (or rely on the default).
- `foundationModelsDefault`: `supportsToolLoop: true` (irrelevant — FM uses native orchestration; default is fine).
- `smolLM2Test`: `supportsToolLoop: false` (27% BFCL — spec §6).

- [ ] **Step 4: Thread it into `LlamaEngine` via the loader**

In `EngineHost.swift` `makeProductionLoader`, the `.llama` branch constructs `LlamaEngine(runtimeReusing: runtime)`. Change to `LlamaEngine(runtimeReusing: runtime, supportsToolLoop: entry.supportsToolLoop)`.

- [ ] **Step 5: Verify**

Run: `cd b0tKit && swift test --filter InferenceModelCatalogueTests` → PASS.
Run: `cd b0tKit && swift test` → full suite green; `cd b0tKit && swift build` clean.

- [ ] **Step 6: Commit**

```bash
git add b0tKit/Sources/b0tBrain/InferenceModelCatalogue.swift b0tKit/Sources/b0tLlama/EngineHost.swift b0tKit/Tests/b0tBrainTests/InferenceModelCatalogueTests.swift
git commit -m "feat(b0tBrain,b0tLlama): curated supportsToolLoop gate, threaded into LlamaEngine (tool loop)"
```

---

### Task 7: Integration — gated live test + full suite + tracker

**Files:**
- Modify: `b0tKit/Tests/b0tLlamaLiveTests/` (the gated live target — find the existing `Q6ToolCallLiveTests` or equivalent)
- Modify: `docs/IMPLEMENTATION.md`

- [ ] **Step 1: Extend the gated live test**

Find the existing gated live tool-call test (grep `Q6ToolCallLiveTests` / `LIVE_LLAMA` / `Q6_HOST` under `b0tKit/Tests`). Add a test, gated by the same env flag, that exercises the FULL loop end-to-end on a real downloaded model: build a `LlamaEngine(runtimeReusing: realRuntime, supportsToolLoop: true)`, call `generate(context:generating: ConversationResponse.self)` with a tools array (use the real `b0tModules` tools if the live target can import them, else `TimeTool`-style local fakes that don't need permissions) and a prompt like "what time is it?", and assert a `ToolCallRecord` was produced and the response text is non-empty. Match the existing gated-test setup (model download/caching, the env-flag guard, how the runtime is loaded). If the live target cannot import `b0tModules`/`b0tCore` tools, keep using a local in-test `Tool` (as in Task 5) so the loop still runs against the real model.

- [ ] **Step 2: Run the full suite (host)**

Run: `cd b0tKit && swift package clean && swift test`
Expected: all green (the gated live tests stay skipped without the flag). Record the new total.

- [ ] **Step 3: Update the tracker**

In `docs/IMPLEMENTATION.md`, note the llama tool-call execute/iterate loop is complete (one-tool-then-answer; spec `docs/specs/phase-2-llama-tool-call-loop.md`), remove it from the "remaining Phase-2 work" list, and update the test count. Note the deferred items (multi-step chains; runtime `supportsToolLoop` auto-detection).

- [ ] **Step 4: Commit**

```bash
git add b0tKit/Tests docs/IMPLEMENTATION.md
git commit -m "test(b0tLlama)+docs: gated live tool-loop test; tracker — llama tool loop complete (Phase 2)"
```

---

## Self-review notes (for the executor)

- **Spec coverage:** §4 execution bridge → Task 1. §3/§5 two-pass flow + gate → Tasks 3, 4, 5. §6 capability gate → Task 6. §7 failure/permission → Task 5 (catch + unknown/none fall-through; permission surfaces via tool Output, no new code). §8 testing → embedded per task + Task 7 (gated live). §9 out-of-scope respected.
- **Risk-first:** Task 1 is the existential-opening spike; if the SDK path is unavailable the executor reports before downstream tasks build on it (fallback: per-tool `callJSON`).
- **Type consistency:** `ToolRunResult`(outputSummary/argumentsSummary) is produced by `ToolExecutor.execute` (Task 1) and consumed in `LlamaEngine.generate` (Task 5). `ToolGate.grammar/systemPrompt/isNone/argumentsJSON/noneName` (Task 3) used verbatim in Task 5. `LlamaGenerating`(contextWindow + generate) (Task 2) is the type of `LlamaEngine.runtime` (Task 4) and the test `ScriptedGenerator` (Task 5). `supportsToolLoop` (Task 6) gates `generate` (Task 5).
- **Watch items:** (a) Task 1 — exact FoundationModels `GeneratedContent(json:)` / `Arguments(GeneratedContent)` / `jsonString` API; (b) Task 2 — `LlamaRuntime` actor-vs-class + `contextWindow` isolation; (c) Tasks 3/5 — real `JSONValue` case names + `AssembledContext`/`ConversationResponse` shapes; (d) Task 4 — audit `LlamaEngine(` call sites after widening `runtimeReusing:` to `any LlamaGenerating`.
