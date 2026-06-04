# Phase 2 re-open — inference engine abstraction (spec)

**Status:** Approved 2026-05-30 — design of record for the Phase 2 re-open
**Date:** 2026-05-30
**Source:** amendment 2026-05-29 §2/§3/§7/§8; [ADR-0012](../decisions/0012-inference-engine-agnostic.md), [ADR-0015](../decisions/0015-content-format-boundary-slot-assembly.md)
**Forks resolved 2026-05-30:** llama.cpp via official XCFramework + thin wrapper; tool-calling via tool-capable catalogue + lighter harness with graceful degradation; structured output via dual-conformance + schema→GBNF.

This spec covers the architecture only. It decomposes into a TDD task plan (`docs/plans/`) as the next step. No code is written until both this spec and that plan are approved.

---

## 1. Goal and non-goals

**Goal.** Make `b0tCore` inference engine-agnostic: Foundation Models stays as a first-class engine (the default where the device supports it), and a llama.cpp-backed engine runs downloadable open-weight GGUF models (the default otherwise, switchable everywhere). Behaviour of the existing conversation/heartbeat flows is preserved on the FM path.

**Non-goals (this re-open).**
- The Processor inspector *visual* design beyond functional wiring (waits on Jamee's UI materials / §14 Q1–Q2 aesthetic).
- The robust open-weight tool-call loop for *weak* models — we target tool-capable models and degrade gracefully (see §6).
- Multi-b0t, modular face, anything in ADR-0013's v2 set.

**Preserved invariants.** `b0tBrain` is untouched. The markdown-brain layer, the OpenClaw journal, the heartbeat scheduler, and privacy posture (no cloud inference; one sanctioned download call) all stand.

---

## 2. The seam today (verified against the code)

- **`LanguageModelClient`** (`b0tCore/Model/LanguageModelClient.swift`) is already the abstraction point: `generate<Output: Generable>(context:generating:) async throws -> (Output, [ToolCallRecord])`. It leaks two FM-only types — the **`Output: Generable`** constraint and **`AssembledContext.tools: [any Tool]`** (FM's `Tool`). Decoupling these two leaks is the core of the abstraction.
- **`ContextAssembler`** already emits a clean `(systemInstructions: String, userPrompt: String)` pair and hands raw strings to FM, which applies its own chat template invisibly. So the **content/format split (ADR-0015) partially exists** — FM is silently doing the format layer. The minimal "system + user" message shape is already present; full slot-based assembly is an additive refinement, not a prerequisite.
- **Decision types** (`TickDecision`, `ConversationResponse`, `MemoryObservation`, `RelationshipNote`, `MoodTransition`) are `@Generable` with `@Guide` field descriptions. Those descriptions are the source for both the GBNF schema and the prompt-side structure description on the llama path.
- **Call sites:** `ConversationManager.respondWithFallback` and `HeartbeatManager.tick` call `client.generate(...)`. They take `client: any LanguageModelClient` by injection — so swapping the concrete engine needs no call-site change once the protocol is decoupled.
- **`StubLanguageModelClient`** (test target) is the deterministic test seam; the gated live-FM tests exercise the real path.

---

## 3. Target architecture

### 3.1 The protocol

Rename/evolve `LanguageModelClient` → **`InferenceEngine`** (keeping a typealias for transition), decoupled from FM:

```swift
public protocol InferenceEngine: Sendable {
    var contextWindow: ContextWindow { get }           // model-derived; drives budgeting
    var capabilities: EngineCapabilities { get }        // e.g. supportsTools, supportsToolLoop
    func generate<Output: StructuredDecodable>(
        request: InferenceRequest,                       // engine-neutral (was AssembledContext)
        decoding outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord])
}
```

Two conformers:
- **`FoundationModelsEngine`** — wraps today's `LiveLanguageModelClient` essentially unchanged (the `LanguageModelSession` + `@Generable` + transcript extraction logic moves behind it verbatim).
- **`LlamaEngine`** — wraps a thin b0t-owned `LlamaRuntime` over the ggml-org XCFramework.

### 3.2 Decoupling structured output — `StructuredDecodable`

The neutral constraint both engines satisfy:

```swift
public protocol StructuredDecodable: Sendable {
    static var jsonSchema: JSONSchema { get }   // for GBNF + prompt description
    init(fromStructuredJSON: Data) throws       // llama decode path
}
```

- FM conformance: decision types remain `@Generable`; the FM engine ignores `jsonSchema` and uses the macro path as today.
- Llama conformance: decision types also become `Codable`; output is constrained by a **GBNF grammar** applied via `llama_sampler_init_grammar`, and the `@Guide`/shape descriptions are rendered into the prompt (llama.cpp does *not* inject the schema into the prompt — verified).
- **GBNF is pre-generated offline, not converted at runtime (refined 2026-05-30).** Research confirmed `json_schema_to_grammar` lives in llama.cpp's `common/`, which is **not exported by the xcframework**. So we generate the GBNF grammar for each of our small, fixed set of decision types **offline** (via llama.cpp's `examples/json_schema_to_grammar.py`, a documented one-time build step) and commit the result as a `gbnfGrammar` string on each type. Single source of truth = the committed grammar, regenerated when a type changes.
- Decision types thus carry `@Generable` (FM) **and** `Codable` (llama JSON decode) **and** `StructuredOutput` with a `gbnfGrammar` (llama constraint).

### 3.3 The format layer

Per ADR-0015, each engine owns wrapping content into the model's token sequence:
- FM applies its own template (as today).
- `LlamaRuntime` drives generation through llama.cpp's chat/messages path so the **model's own embedded GGUF chat template** is applied automatically — the format follows the weights on model switch, no per-model prompt-syntax code.
- `ContextAssembler`'s `(systemInstructions, userPrompt)` becomes an engine-neutral `InferenceRequest` carrying role-tagged messages (minimal: system + user). The richer `slot` field (ADR-0015) is folded into `AssembledContext`/manifest later and is **not** a blocker for this re-open.

### 3.4 Tools, decoupled

`AssembledContext.tools: [any Tool]` (FM `Tool`) becomes an engine-neutral tool descriptor (name, description, parameter JSON schema). The FM engine adapts descriptors → FM `Tool`; the llama engine uses them for the tool-call harness (§6). The existing `b0tModules` tools expose this descriptor.

---

## 4. Capability detection, default, and switching

- At startup, detect FM availability (`SystemLanguageModel.default.isAvailable`, already checked). FM available → `FoundationModelsEngine` is the pre-selected default. Otherwise `LlamaEngine` with the user's selected/downloaded model.
- **Switchable everywhere:** the user may select any catalogue entry (FM or a downloadable model) regardless of device, subject to download/RAM checks.
- **Selection state lives in markdown** (proposed): a processor config file — `identity/processor.md` frontmatter (`engine`, `model_id`, inference params like `temperature`) — consistent with the markdown-brain thesis and the Processor organ. Model *binaries* live outside markdown in Application Support. *(Open: exact file location — §9.)*

---

## 5. Model download manager + lifecycle (Stage C)

- **Download manager:** resumable `URLSession` background downloads from **pinned source URLs** (per-model, with SHA-256 integrity check). Storage- and RAM-aware: refuses/warns when the model won't fit (the ~2–3GB resident ceiling on 6GB devices caps the catalogue at ~1–2B quantised). Graceful storage-full handling. This is the **one sanctioned outbound network call** (privacy manifest + dependency audit per ADR-0012).
- **Lifecycle:** load/unload to stay under jetsam; unload on memory pressure; one resident model at a time.
- **Catalogue:** the `b0tBrain` catalogue gains model entries (FM + the downloadable trio). Couples to §14 Q6 — the trio is curated toward **tool-calling competence** (see §6). Per-model: id, source URL, checksum, size, context window, license/disclosure text (shown in the Processor inspector), quant level.

---

## 6. Tool-calling on the llama path

Per the resolved fork: **curate for competence + lighter harness + graceful degradation.**
- The downloadable catalogue (§14 Q6) favours models with decent native tool/function-calling (e.g. Qwen variants).
- `LlamaEngine` runs a **GBNF-constrained tool-call loop**: constrain emission to a tool-call grammar, parse, execute via existing `b0tModules` tools, feed results back, iterate (bounded).
- `EngineCapabilities.supportsToolLoop` gates it: a model that tool-calls poorly is marked tools-off and the b0t degrades to conversation/heartbeat reasoning without live tools (and says so honestly, in voice). FM keeps its native tool orchestration unchanged.

---

## 7. Token metering (amendment §8)

- Budgeting re-bases on `engine.contextWindow` (the hardcoded `3500`/`4096` go away). Counts use the **active model's tokenizer** (FM estimate vs llama's real tokenizer), recomputed on content change / model swap, including template/structural overhead.
- Per-slot/per-organ subtotals are surfaced so the Processor gauge can show usage against the window denominator, and each `.md` can report its own count. Implementation of the *gauge UI* is Stage D; the *data* is produced here.

---

## 8. Staging, error handling, testing

**Stages** (each buildable/testable; plan decomposes into TDD tasks):
- **A — Abstraction (pure refactor).** `InferenceEngine` + `StructuredDecodable` + neutral `InferenceRequest`/tool descriptors; FM becomes a conformer; decision types gain `Codable`/`jsonSchema`. **No behaviour change; all 279 tests stay green.** This is the lowest-risk, highest-value first landing.
- **B — Llama engine.** XCFramework integration (Swift/C++ interop), `LlamaRuntime`, load/generate, structured output via schema→GBNF, embedded-template format layer.
- **C — Download manager + lifecycle + catalogue + capability default/switch + processor config.**
- **D — Processor inspector wiring + token-metering data → gauge.**

**Error handling.** `LanguageModelClientError` generalises to engine-neutral cases: `modelUnavailable`, `modelNotDownloaded`, `downloadFailed`, `insufficientStorage`/`insufficientMemory`, `exceededContextWindowSize`, `malformedStructuredOutput`, `engineFailed`. The graduated context-overflow fallback in `ContextAssembler` is preserved and re-based on the variable window.

**Testing.**
- Stage A: existing 279 tests are the regression net (FM path must stay green); add unit tests for `StructuredDecodable` schema derivation + round-trip decode.
- A new **`StubInferenceEngine`** generalises the existing stub for deterministic tests of both paths.
- Llama path: gated live tests (`LIVE_TESTS=1`-style, mirroring the Phase 2/3 pattern) against a small bundled-or-downloaded test GGUF — schema→GBNF produces valid decodable output; tool-call loop executes a known tool.
- Privacy audit: confirm the XCFramework makes no network calls of its own; the only egress is the download manager to pinned URLs.

---

## 9. Open questions (do not silently resolve)

1. **Processor config file location** — **Resolved 2026-05-30:** `identity/processor.md` frontmatter (`engine`, `model_id`, inference params), thesis-consistent and surfaced by the Processor organ. Model binaries live in Application Support, not markdown.
2. **§14 Q6 model lineup + quant** — **Desk-half resolved 2026-06-02** (`docs/specs/phase-2c-q6-model-lineup-validation.md`): trio locked — default **Qwen3-1.7B** (Apache-2.0), opt-in **Llama 3.2 1B** ("Built with Llama"), third **Qwen2.5-1.5B-Instruct** (Apache-2.0); all Q4_K_M. SmolLM2 disqualified (27% BFCL) → test-fixture only. **Device-half pending:** the on-device validation protocol (RAM fit on the 6GB floor, template gate, latency, tool-call reliability) runs on the iPhone 13 Pro before catalogue rows + pinned SHAs are committed.
3. **`jsonSchema` derivation mechanism** — macro/codegen vs hand-written per type. Plan picks the lightest single-source-of-truth approach during Stage A.
4. **Bundled test GGUF** — **Resolved 2026-05-30 (research-grounded):** SmolLM2-360M-Instruct GGUF Q4_K_M (~271 MB, Apache-2.0, ChatML) **downloaded to a local cache on first run** (`~/Library/Caches/b0t-tests/models/`), not committed to git; llama live tests gated like the existing `LIVE_TESTS` integration tests so default `swift test` stays fast and offline.

5. **Chat-template support is a catalogue constraint (new 2026-05-30; reframed 2026-06-02 by [ADR-0018](../decisions/0018-llama-tool-calling-via-gbnf-pure-c.md)).** `llama_chat_apply_template` supports a **pre-defined template list, not arbitrary Jinja** — and per ADR-0018 this is a *consequence of b0t's pure-C `b0tLlama` integration*, not a llama.cpp-wide limit (the Jinja/minja autoparser lives in the C++ `common` layer, confirmed **not** in the b9415 xcframework). The per-model go/no-go gate is therefore: **does the model's GGUF-embedded template get recognized by `llama_chat_apply_template`?** — verified on-device per model. Tool-calling uses a **GBNF-constrained harness** (§6 / ADR-0018), so BFCL competence is a *decision-quality* signal only; output format is grammar-enforced.

6. **Risk to watch:** llama.cpp issue #21571 (Apr 2026) reported structured-output sampler-init failures; resolution unconfirmed. The B3 grammar tasks must verify grammar sampling actually works against the pinned build before relying on it.

---

## 10. What this unblocks downstream

The slot-based assembly refinement (ADR-0015 full form), per-organ token attribution UI, and the Processor inspector's model-management surface all build on this. The v2 modular-face and multi-b0t work (ADR-0013) is independent of it.
