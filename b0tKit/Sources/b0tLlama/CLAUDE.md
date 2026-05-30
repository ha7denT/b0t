# b0tLlama

A llama.cpp-backed `InferenceEngine` for `b0tCore`. Isolates the binary
dependency so `b0tCore` stays binary-free. Added in Phase 2 Stage B (ADR-0012 /
`docs/specs/phase-2-inference-engine-abstraction.md`).

## Dependency

- Consumes the official `ggml-org/llama.cpp` **XCFramework** as a SwiftPM
  `binaryTarget` named `llama`, pinned to build **b9415** in `Package.swift`
  (`url` + `checksum`). Update both together when bumping the build.
- **Pure C API** — `import llama` exposes `include/llama.h` (`extern "C"`).
  **No Swift/C++ interop** (`-cxx-interoperability-mode` is not used). The C
  sampler imports as `UnsafeMutablePointer<llama_sampler>`; model/context/vocab
  as `OpaquePointer`.
- The XCFramework ships iOS device + iOS sim + macOS-universal slices, so the
  macOS-host `swift test` links and runs it.

## Public API

- `LlamaRuntime` — `actor` wrapping the C API. One resident GGUF model per
  instance. `init(modelPath:contextLength:)` loads the model (clamps the context
  to the model's trained maximum, exposed as `nonisolated let contextWindow`);
  `generate(messages:grammar:maxTokens:)` applies the model's GGUF-embedded chat
  template (`llama_model_chat_template` + `llama_chat_apply_template` — a
  pre-defined template family, not Jinja), tokenizes, samples, and returns text.
  When `grammar` is non-nil it adds a `llama_sampler_init_grammar(vocab, gbnf,
  "root")` sampler **before** temp + dist. `llama_backend_init` runs once
  (process-global) and is intentionally never freed for a single resident model;
  the model/context are freed in `isolated deinit`.
- `LlamaChatMessage(role:content:)` — neutral role/content message;
  `LlamaRuntimeError` — load/context/template/decode/timeout failures.
- `LlamaEngine` — `InferenceEngine` conformer. `init(modelPath:contextLength:)`
  builds a `LlamaRuntime`. `generate(context:generating:)` renders the system
  instructions + user prompt + the type's `jsonShapeHint` (llama.cpp does not
  inject the schema), generates under the type's pre-generated GBNF grammar
  (`Output.gbnfGrammar`, from `b0tCore`'s `Resources/Grammars/`), then extracts
  the first balanced `{...}` (`firstJSONObject`) and decodes it via `Codable`.
  Exposes `contextWindow` as a plain property (Stage C lifts it onto the
  protocol).

## Structured output — grammar enforcement is ON

The pre-generated GBNF grammars live in `b0tCore` (`StructuredOutput.gbnfGrammar`).
llama.cpp issue #21571 (Apr 2026) reported sampler-init failures for structured
output; **`llama_sampler_init_grammar` works against pinned build b9415** —
verified by `test_grammarConstrainedOutput_isParseableJSON` (grammar in
isolation) and `test_llamaEngine_decodesTypedConversationResponse` (e2e). If a
future build regresses this, `firstJSONObject` + tolerant decode is the
documented grammar-off fallback (`LlamaEngine.generate` already tolerates an
empty grammar by passing `nil`).

## Tools — OUT of Stage B

`LlamaEngine` never returns `ToolCallRecord`s (the SmolLM2 test model has no
tool-calling). Tool support waits on a validated tool-capable model (§14 Q6) in
or before Stage C.

## Testing

- Live tests are gated by `LIVE_LLAMA=1` (skip otherwise so default `swift test`
  stays offline/fast). Run: `LIVE_LLAMA=1 swift test --package-path b0tKit
  --filter LlamaRuntimeLiveTests`.
- `LlamaModelCache` downloads `bartowski/SmolLM2-360M-Instruct-GGUF` Q4_K_M
  (~271 MB, Apache-2.0, ChatML, no tools) to `~/Library/Caches/b0t-tests/models/`
  on first run; not git-committed.
- Three live cases: non-empty generation (B1), grammar-isolation JSON parse, and
  the `LlamaEngine` typed-decode e2e.

## Stage C (not built here)

Capability detection + default engine selection, the production download manager
+ jetsam lifecycle + model catalogue, `identity/processor.md` config,
variable-window budgeting on the protocol, and the llama tool-call harness.
