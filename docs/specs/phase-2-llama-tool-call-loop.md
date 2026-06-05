# Phase 2 · Llama tool-call execute/iterate loop

**Status:** Design of record. Approved 2026-06-05 (brainstorm with Jamee).
**Phase:** 2 (engine-agnostic inference). Completes the llama-path tool-calling that [ADR-0018](decisions/0018-llama-tool-calling-via-gbnf-pure-c.md) prescribes and that `phase-2-inference-engine-abstraction.md` §6 specified.
**Builds on:** Stage B (`LlamaEngine`/`LlamaRuntime`, GBNF structured output), the single-shot `LlamaToolCallLoop.pickTool` (built), Stage D's `EngineHost`/catalogue wiring.

---

## 1. Purpose

The downloadable-model (llama) path can today produce GBNF-constrained structured output and *pick* a tool single-shot (`LlamaToolCallLoop.pickTool`), but it cannot **execute** the chosen tool, feed the result back, and produce a final answer. So a downloaded model — unlike Foundation Models, which orchestrates tools natively inside `LanguageModelSession` — can't actually complete a tool-assisted turn. This closes that gap, delivering the "own your brain" promise end-to-end: a downloaded model can answer "what's on my calendar?" by calling the calendar tool and replying with the result.

Per [ADR-0018](decisions/0018-llama-tool-calling-via-gbnf-pure-c.md), this stays on the **pure-C boundary** with a GBNF-constrained harness — no minja/`common`/C++ interop.

## 2. Scope decisions (settled in brainstorm)

| Decision | Choice |
|---|---|
| Loop depth | **One tool, then answer.** The model picks at most one tool; we execute it and it produces the final answer. Matches small (1–2B) model reliability ("decision competence", ADR-0018). Multi-step chains → later. |
| Overall shape | **Approach A** — two-pass inside `LlamaEngine.generate` (gate → execute → answer). Keeps the `InferenceEngine` contract uniform with FM (tools handled inside the engine); serves chat + heartbeat transparently. |
| Execution bridge | Swift **implicit existential opening** in a b0tCore `ToolExecutor` — no per-tool code, no FM session, pure-C boundary preserved. |
| Capability gate | Curated `supportsToolLoop: Bool` on the catalogue entry (true for the validated trio); runtime auto-detection deferred. |

## 3. Components

**New**
- `ToolExecutor` (b0tCore) — executes an `any Tool` from JSON arguments via existential opening; returns output + argument summaries.
- `LlamaGenerating` protocol (b0tLlama) — a one-method seam (`generate(messages:grammar:maxTokens:) async throws -> String`) that `LlamaRuntime` conforms to, so the two-pass orchestration is unit-testable with a fake generator.
- Tool-gate additions (b0tLlama, `ToolCalling.swift` + `ToolCallGrammarBuilder`) — the gate grammar/envelope allows a `"none"` choice alongside the tool names.

**Edited**
- `LlamaEngine` (b0tLlama) — `generate` becomes the two-pass gate→execute→answer flow; `init` accepts `supportsToolLoop` and uses `LlamaGenerating`.
- `InferenceModelEntry` (b0tBrain) — add curated `supportsToolLoop: Bool` (default true), set per trio entry; the FM entry's value is irrelevant (FM keeps native orchestration).
- `EngineHost.makeProductionLoader` (b0tLlama) — pass `entry.supportsToolLoop` into `LlamaEngine`.

**Unchanged**
- `FoundationModelsEngine` — keeps native tool orchestration.
- `ConversationManager`/`HeartbeatManager` — already thread `[ToolCallRecord]` from `generate` into the journal (`tools_called:`) and tool-event publisher; the loop simply makes the llama path populate those records.

## 4. Tool-execution bridge — `ToolExecutor` (b0tCore)

```swift
public struct ToolRunResult: Sendable, Equatable {
    public let outputSummary: String       // tool Output, stringified (fed back + recorded)
    public let argumentsSummary: String    // compact JSON args (for the ToolCallRecord)
}

public enum ToolExecutor {
    /// Find a tool by name in the assembled tool set.
    public static func tool(named name: String, in tools: [any Tool]) -> (any Tool)?

    /// Execute `tool` with JSON arguments. Builds the tool's typed `Arguments`
    /// from `GeneratedContent(json:)` via implicit existential opening, calls it,
    /// and stringifies the output.
    public static func execute(tool: any Tool, argumentsJSON: String) async throws -> ToolRunResult
}
```

Implementation note: a private generic `run<T: Tool>(_ t: T, _ gc: GeneratedContent)` recovers the concrete type when `any Tool` is passed (Swift opens the existential), constructs `T.Arguments(gc)` (FM `@Generable` args conform to `ConvertibleFromGeneratedContent`), `await t.call(arguments:)`, and renders the output via its `GeneratedContent` (`jsonString`) or `String(describing:)`. b0tCore already imports `FoundationModels` and owns `AssembledContext.tools`, so this is the right home; b0tLlama calls it.

**Fallback (only if the primary path fails to compile/behave):** a minimal `callJSON(_:) async throws -> String` protocol adopted by the ~5 b0tModules tools. The first implementation task validates the existential-opening path with a test before committing to it.

## 5. Two-pass flow — `LlamaEngine.generate`

```
generate<Output: StructuredOutput>(context, generating: Output)
  if context.tools.isEmpty || !supportsToolLoop:
      return singlePassStructured(context, Output)        // today's behaviour, records = []
  // Pass 1 — tool gate
  gateGrammar = ToolCallGrammarBuilder.grammar(toolNames: names + ["none"])   // "none" = reserved skip name
  envelope = parse(runtime.generate(gatePrompt(tools), gateGrammar))
  records = []
  augmentedContext = context
  if let call = envelope, call.tool != "none", let tool = ToolExecutor.tool(named: call.tool, in: context.tools):
      do {
          result = try await ToolExecutor.execute(tool: tool, argumentsJSON: call.arguments.jsonString)
          records.append(ToolCallRecord(toolName: call.tool, argumentsSummary: result.argumentsSummary,
                                        outputSummary: result.outputSummary, timestamp: now))
          augmentedContext = context.injectingToolResult(tool: call.tool, summary: result.outputSummary)
      } catch {
          augmentedContext = context.injectingToolResult(tool: call.tool, summary: "(tool error: \(error))")
          records.append(ToolCallRecord(toolName: call.tool, argumentsSummary: call.arguments.jsonString,
                                        outputSummary: "errored", timestamp: now))
      }
  // unknown tool name / unparseable / "none" → fall through with records unchanged
  // Pass 2 — final structured answer (existing GBNF structured path) over augmentedContext
  (output, _) = try singlePassStructured(augmentedContext, Output)
  return (output, records)
```

- `singlePassStructured` is the current `generate` body factored out (system + user + `Output.jsonShapeHint`, generate under `Output.gbnfGrammar`, decode JSON). Reused for the answer pass.
- "Injecting the tool result" appends a short line (e.g. `tool calendar.upcoming_events result: <summary>`) to the user-content/system context for pass 2 — the same shape FM gets from its tool transcript, so the model can ground its answer.
- At most two `runtime.generate` calls per turn.
- `now` comes from an injected clock or `Date()` consistent with the rest of b0tLlama (no `Date.now` ban here — that's a workflow-script constraint, not app code; match existing b0tLlama timestamp usage).

## 6. Capability gate — `supportsToolLoop`

- Add `public let supportsToolLoop: Bool` to `InferenceModelEntry` (default `true`). The validated trio (Qwen3-1.7B, Llama-3.2-1B, Qwen2.5-1.5B) all passed tool-call validation (88–100%, spec §6a) → `true`. SmolLM2 test fixture → `false` (27% BFCL).
- `EngineHost.makeProductionLoader` passes `entry.supportsToolLoop` into `LlamaEngine(runtimeReusing:supportsToolLoop:)`.
- When `false`, `LlamaEngine.generate` skips the gate entirely — the b0t reasons without live tools (and the system prompt / voice already degrade honestly per ADR-0018). Runtime auto-detection of tool competence is out of scope.

## 7. Failure & permission handling

- **Unparseable gate / unknown tool** → treat as `"none"`, skip to the answer pass (GBNF makes malformed output rare; the `firstJSONObject` guard + a nil-parse both route here). Log in DEBUG.
- **Tool `call` throws** → inject an honest error note into the answer-pass context and record the call as errored; the turn still completes.
- **Permission-gated tools** (calendar/reminders/health) already return a `permissionDenied: true` Output rather than throwing — that surfaces in `outputSummary`, is fed to the answer pass, and is recorded, exactly as on the FM path. No new permission UI.

## 8. Testing

- **`ToolExecutor`** (b0tCore) — a fake `Tool` with a `@Generable` Arguments type; assert JSON args → typed `call` → expected output/summary; assert `tool(named:in:)` lookup; assert an unknown name returns nil.
- **Gate grammar + parse** (b0tLlama) — pure: grammar includes the tool names + `"none"`; `parse` handles a tool envelope, the `"none"` envelope, and malformed→nil.
- **Two-pass orchestration** (b0tLlama) — `LlamaEngine` over a fake `LlamaGenerating` that returns a canned pass-1 envelope then canned pass-2 JSON; assert: (a) the tool executed and produced the expected `ToolCallRecord`; (b) the tool result reached the pass-2 prompt; (c) `"none"`/no-tools path makes a single call with `records == []`; (d) `supportsToolLoop == false` skips the gate.
- **Gated live test** — extend `Q6ToolCallLiveTests` (or the Q6 harness) to run gate→execute→answer end-to-end on the real trio, gated by the existing `LIVE_LLAMA`/`Q6_HOST` flags.
- No regressions: existing `b0tLlamaTests` + the full SPM suite stay green.

## 9. Out of scope

- **Multi-step tool chains** (the "bounded multi-step" option) — v1 is one tool then answer.
- **Runtime/automatic `supportsToolLoop` detection** — curated bool only.
- **The FM path** — unchanged; it keeps native orchestration.
- **New tools or per-tool argument schemas** — uses the existing 5 b0tModules tools as-is.
