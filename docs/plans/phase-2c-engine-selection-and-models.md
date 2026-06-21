# Stage C — Engine selection, model download & lifecycle, variable budgeting (plan)

> **STATUS — COMPLETE (C1–C4, 2026-06-05).** This plan is now historical. As-built:
> C1 variable budgeting + C2 `processor.md`/`CapabilityDetector` (merged earlier);
> C3 `InferenceModelCatalogue` (b0tBrain, real verified trio rows — the Q6-gated
> placeholders below were resolved, see `docs/specs/phase-2c-q6-model-lineup-validation.md`)
> + `ModelDownloadManager` + `ModelStore` (b0tLlama); C4 `EngineSelector` (b0tCore)
> + `b0tApp.resolveClient`. The llama **tool-call harness** shipped as a single-shot
> GBNF loop (`LlamaToolCallLoop`, ADR-0018); execute/iterate + Stage D UI remain.
> The resume point is `docs/IMPLEMENTATION.md`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make the engine **user-selectable and capability-defaulted** end to end: a markdown `identity/processor.md` config drives which engine/model runs; budgeting re-bases on the active model's real context window; a download manager + lifecycle bring downloadable models onto the device; and `b0tApp` constructs the right engine at launch.

**Architecture:** Six sub-stages, front-loading the Q6-independent foundations. `b0tCore` gains `InferenceEngine.contextWindow` and instance-based budgeting. `b0tBrain` gains a `processor.md` accessor and a *new* inference-model catalogue (separate from the existing face/`BotModel` catalogue). A new `b0tLlama` download manager + lifecycle handle GGUF acquisition/residency. `b0tApp` selects FM-when-available-else-Llama, honouring the user's `processor.md` override.

**Tech Stack:** Swift 6, SwiftPM, Foundation `URLSession` (background download), b0tCore/b0tBrain/b0tLlama, XCTest.

**Scope note — Stage C of the Phase 2 re-open** (`docs/specs/phase-2-inference-engine-abstraction.md`). Stages A (abstraction) + B (llama engine) are merged. **Stage D** (Processor inspector + token-metering UI) follows and is gated on Hayden's UI designs (§14 Q1/Q2).

### Q6 boundary (what's buildable now vs. what waits on the model-lineup validation)

- **Buildable + testable NOW (Q6-independent):** C1 variable budgeting, C2 `processor.md` + capability detection, C3 download manager + lifecycle *mechanism* (validated against the cached **SmolLM2-360M** test model), C4 `b0tApp` engine-selection wiring.
- **Q6-GATED (placeholder now, finalized at validation):** the **production catalogue entries** (real Qwen3 1.7B / Llama 3.2 1B / third-model URLs, pinned revisions, checksums, sizes, context windows, supported chat-template family) and the llama **tool-call harness** (needs a tool-capable model). C3 ships the catalogue *structure* + the SmolLM2 entry; production rows land at Q6.

### Decision adopted (download source — ADR-0012 "pinned, declared source")

Models download **directly from their Hugging Face repos at a pinned revision (commit SHA in the URL) + SHA-256 checksum** — no b0t-hosted mirror in v1. This satisfies ADR-0012's "pinned, declared source", matches the already-working test download, and avoids hosting cost. Revisit only if HF availability/licensing forces a mirror. (Flagged here, not silently resolved.)

---

## Sub-stage C1 — variable, model-derived context budget (Q6-independent; DETAILED)

Removes the hardcoded `3500`/`4096`; budgeting follows the active engine's window. Foundational for everything else and fully unblocked.

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Model/LanguageModelClient.swift` (add `contextWindow` to `InferenceEngine`)
- Modify: `b0tKit/Sources/b0tCore/Model/LiveLanguageModelClient.swift` (`FoundationModelsEngine.contextWindow`)
- Modify: `b0tKit/Sources/b0tCore/Model/StubLanguageModelClient.swift` (configurable `contextWindow`)
- Modify: `b0tKit/Sources/b0tLlama/LlamaEngine.swift` (expose `contextWindow` to satisfy the protocol — already reads `runtime.contextWindow`)
- Modify: `b0tKit/Sources/b0tCore/Context/ContextAssembler.swift` (instance `limit` derived from an injected window; drop the `static let limit = 3500`)
- Modify: `b0tKit/Sources/b0tCore/ConversationManager.swift` + `HeartbeatManager.swift` (pass `client.contextWindow` into the assembler)
- Test: `b0tKit/Tests/b0tCoreTests/ContextBudgetWindowTests.swift` (create)

- [x] **Step 1: Failing test** — a stub engine with `contextWindow: 2048` yields an assembler `limit` of `2048 - responseReserve` (define `responseReserve = 600`, so 4096→3496 keeps existing behaviour ~3500). Assert `AssembledContext.budget.limit == 2048 - 600` when the assembler is built with `contextWindow: 2048`.

```swift
import XCTest
@testable import b0tCore

final class ContextBudgetWindowTests: XCTestCase {
    func test_limitDerivesFromContextWindow() async throws {
        let bot = Bot.empty(at: FileManager.default.temporaryDirectory)
        let assembler = ContextAssembler(bot: bot, store: BotStore(), contextWindow: 2048)
        let ctx = try await assembler.assemble(mode: .conversation(userPrompt: "hi"))
        XCTAssertEqual(ctx.budget.limit, 2048 - ContextAssembler.responseReserve)
    }
}
```

- [x] **Step 2: Run → fails** (`ContextAssembler` has no `contextWindow:` init param). `swift test --package-path b0tKit --filter ContextBudgetWindowTests`.
- [x] **Step 3: Implement**
  - `InferenceEngine`: add `var contextWindow: Int { get }`.
  - `FoundationModelsEngine`: `public var contextWindow: Int { 4096 }` (FM's window; no query API — document the constant).
  - `StubInferenceEngine`: add `let contextWindow: Int` with `init(contextWindow: Int = 4096, handler:)`, defaulted so existing tests are untouched.
  - `LlamaEngine`: `public var contextWindow: Int { runtime.contextWindow }` (`runtime.contextWindow` is `nonisolated let`).
  - `ContextAssembler`: add `public static let responseReserve = 596`; replace `static let limit = 3500` with `private let limit: Int`; add `contextWindow: Int = 4096` to `init`, set `self.limit = max(0, contextWindow - Self.responseReserve)`. (Default 4096 → limit 3500, preserving all existing tests.)
  - `ConversationManager`/`HeartbeatManager`: build the assembler with `contextWindow: client.contextWindow`.
- [x] **Step 4: Run → passes**, then full `swift test --package-path b0tKit` (292 executed, 3 skipped, 0 failures) and `xcodebuild ... -scheme b0t` BUILD SUCCEEDED.
- [x] **Step 5: Commit** — `feat(b0tCore): variable context-window budgeting via InferenceEngine.contextWindow (Stage C1)` — SHA `8dc51af`

---

## Sub-stage C2 — `identity/processor.md` config + capability detection (Q6-independent)

The markdown brain owns engine/model selection (ADR-0015 content layer; §9.1 resolved).

- New `default-bot/identity/processor.md` with frontmatter: `engine: foundation_models | llama`, `model_id: <catalogue id>`, optional params (`temperature`, etc.) + prose explaining the processor organ.
- `b0tBrain`: extend `IdentitySection` with a `processor` accessor (mirrors `core`/`principles`), and typed frontmatter reads (`engine`, `modelId`).
- `b0tCore`: a `CapabilityDetector` (FM available via `SystemLanguageModel.default.isAvailable`) → resolves the *effective* engine: honour `processor.md` if its choice is runnable (FM available, or model downloaded), else fall back (FM→llama default or vice-versa) and note it.
- Tests: parse a `processor.md` fixture; capability resolution table (FM-available + engine=fm → fm; FM-unavailable + engine=fm → llama fallback; engine=llama + model present → llama).
- Commit boundary per file group; exact tasks expanded at execution time from this design.

---

## Sub-stage C3 — download manager + model lifecycle (mechanism Q6-independent; catalogue Q6-gated)

- **Inference-model catalogue** (new in `b0tBrain`, separate from face `BotModel`): entries `{ id, engine, sourceURL (pinned revision), sha256, sizeBytes, contextWindow, chatTemplateFamily, license, quant }`. Ship the **SmolLM2-360M** entry (real, for tests) + **placeholder** Qwen3/Llama/third rows marked `// TODO(Q6): validate URL+checksum+size on-device`.
- **Download manager** (`b0tLlama`): resumable `URLSession` background download to Application Support (`Application Support/b0t/models/`), SHA-256 verify on completion, pre-flight free-storage + RAM check (refuse/warn gracefully), progress reporting. Tested against the SmolLM2 entry (gated `LIVE_LLAMA`).
- **Lifecycle:** a `ModelStore`/manager tracking downloaded models + the one resident `LlamaRuntime`; load on selection, free on switch/memory-pressure (jetsam). One resident model.
- Privacy: this is the one sanctioned outbound call (ADR-0012) — confirm no other egress; the manager only hits the pinned catalogue URLs.

---

## Sub-stage C4 — `b0tApp` engine-selection wiring (Q6-independent)

- Replace `initializeHeartbeat`'s hardcoded `try LiveLanguageModelClient()` with: read `processor.md` → `CapabilityDetector` resolves the effective engine → construct `FoundationModelsEngine` or `LlamaEngine(modelPath:)` (from the downloaded model) → inject into `HeartbeatManager` (and the `ConversationManager` chat path). Stub fallback preserved for `--use-stub-client`.
- If the selected llama model isn't downloaded yet, the app surfaces that (b0t voice) and offers download — minimal wiring now; the Processor UI is Stage D.
- App build + a selection unit test (resolver picks the expected engine given fixtures).

---

## Out of scope (Stage D / Q6 / later)

Processor inspector UI + token-metering gauge (Stage D, UI designs); production model lineup validation (Q6); llama tool-call harness (Q6, tool-capable model); per-organ slot-based assembly refinement (ADR-0015 full form).

---

## Self-review

- **Spec coverage:** §5 download/lifecycle → C3; capability default/switch + processor config → C2/C4; variable-window budgeting (§3.4/§7) → C1. ✓ Tools + production lineup explicitly Q6-deferred. ✓
- **Placeholder scan:** C1 is fully bite-sized with exact code; C2–C4 are design-level (to be expanded into TDD tasks at execution, per the established sub-stage rhythm) — this is intentional given the Q6 gate, not a vague placeholder. The Q6-gated catalogue rows are explicitly marked.
- **Type consistency:** `InferenceEngine.contextWindow`, `ContextAssembler.responseReserve`/`init(contextWindow:)`, `StubInferenceEngine(contextWindow:handler:)` used consistently; defaults (4096) preserve existing green tests until callers thread the real value.
