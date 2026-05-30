# Stage B — llama.cpp Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Add a llama.cpp-backed `InferenceEngine` conformer that loads a downloadable GGUF model and produces the same typed decision structs as the Foundation Models engine — via a GBNF-grammar-constrained, JSON-decoded path — without touching the FM path or `b0tCore`'s binary-free build.

**Architecture:** A new SwiftPM target **`b0tLlama`** isolates the dependency: it consumes the official `ggml-org/llama.cpp` **XCFramework** (a pinned `binaryTarget`, pure C API — no Swift/C++ interop) behind a b0t-owned `LlamaRuntime` actor, and exposes a `LlamaEngine` conforming to `b0tCore.InferenceEngine`. `b0tCore` stays binary-free; it only gains a `gbnfGrammar`/`jsonShapeHint` pair on `StructuredOutput` (pure strings). Structured output is enforced by a **pre-generated** GBNF grammar (`llama_sampler_init_grammar`) — the runtime `json_schema_to_grammar` converter is **not** in the xcframework, so grammars are generated offline and committed.

**Tech Stack:** Swift 6, SwiftPM, llama.cpp XCFramework (build `b9415` or newer), C interop via module map, XCTest (gated live tests), Foundation `URLSession` (test-model download).

**Scope note — this is Stage B of the four-stage Phase 2 re-open** (`docs/specs/phase-2-inference-engine-abstraction.md`). Stage A (the `InferenceEngine`/`StructuredOutput` abstraction) is merged. Stage B delivers a `LlamaEngine` that, **given a local model file path**, loads it and returns typed output. Wiring it as the app's capability-detected / user-switchable engine + the download manager + the `identity/processor.md` config is **Stage C**. **Tool-calling on the llama path is OUT of Stage B** — the test model has none, and it needs a validated tool-capable model (§14 Q6); `LlamaEngine.capabilities.supportsTools` is `false` for now.

---

## Research grounding (verified 2026-05-30; see commit trail / spec)

- **XCFramework:** released per build as `llama-b{N}-xcframework.zip` (e.g. `b9415`); consumed via `binaryTarget(url:checksum:)`. Pure C API (`include/llama.h`, `extern "C"`) — **no `-cxx-interoperability-mode`**. Slices: iOS device + sim + macOS universal (so macOS-host `swift test` links it). Ref: `ggml-org/llama.cpp` releases, `mattt/llama.swift/Package.swift`, discussion #4423.
- **Minimal flow (current C names):** `llama_backend_init` → `llama_model_load_from_file` → `llama_init_from_model` → `llama_model_get_vocab`; sampler chain `llama_sampler_chain_init` + `llama_sampler_init_grammar`/`_temp`/`_dist`; `llama_tokenize` → loop(`llama_batch` + `llama_decode` + `llama_sampler_sample` + `llama_vocab_is_eog` + `llama_token_to_piece`); cleanup `llama_sampler_free`/`llama_batch_free`/`llama_model_free`/`llama_free`/`llama_backend_free`. Reference impl: `examples/llama.swiftui/llama.cpp.swift/LibLlama.swift`.
- **Grammar:** `llama_sampler_init_grammar(vocab, gbnf_str, "root")` is public/exported; add to the chain **before** the dist sampler. `json_schema_to_grammar` is in `common/` → **not exported** → generate GBNF offline (`examples/json_schema_to_grammar.py`). Risk: issue #21571 (Apr 2026) reported sampler-init failures with structured output — **B2/B3 must verify grammar sampling works against the pinned build before relying on it.**
- **Chat template:** not auto-applied; `llama_model_chat_template(model, nil)` reads the GGUF-embedded template, `llama_chat_apply_template(...)` applies it. **Pre-defined template list, not Jinja** — catalogue models must use a supported family (constraint for §14 Q6).
- **Test model:** `bartowski/SmolLM2-360M-Instruct-GGUF` Q4_K_M (~271 MB, Apache-2.0, ChatML, **no tool-calling**). **Downloaded to `~/Library/Caches/b0t-tests/models/` on first run, not git-committed.**

## Open dependencies (carried, not resolved here)

- **§14 Q6 model lineup** — Stage B is validated with SmolLM2-360M only. Production models + tool-calling competence are validated in/before Stage C.
- **Pinned xcframework build id + checksum** — Task B1.1 pins the current release; update if a newer build is chosen.

---

## File structure

**Create:**
- `b0tKit/Sources/b0tLlama/LlamaRuntime.swift` — the b0t-owned wrapper actor over the C API.
- `b0tKit/Sources/b0tLlama/LlamaEngine.swift` — `InferenceEngine` conformer.
- `b0tKit/Sources/b0tLlama/LlamaChatMessage.swift` — neutral role/content message + error enum.
- `b0tKit/Sources/b0tCore/Decisions/StructuredOutput+Grammar.swift` — `gbnfGrammar`/`jsonShapeHint` requirements + conformances.
- `b0tKit/Sources/b0tCore/Resources/Grammars/*.gbnf` — committed, offline-generated grammars.
- `b0tKit/Tests/b0tLlamaLiveTests/LlamaModelCache.swift` — gated test-model downloader/cache helper.
- `b0tKit/Tests/b0tLlamaLiveTests/LlamaRuntimeLiveTests.swift` — B1 smoke + B3 e2e (gated by `LIVE_LLAMA=1`).
- `b0tKit/Tests/b0tCoreTests/StructuredOutputGrammarTests.swift` — grammar/hint unit tests (not gated).

**Modify:**
- `b0tKit/Package.swift` — add the `binaryTarget`, the `b0tLlama` target/product, its test target, and `resources: [.process("Resources")]` on `b0tCore`.
- `b0tKit/Sources/b0tCore/Model/StructuredOutput.swift` — (only if needed) keep the base protocol; grammar requirements go in the new extension file to keep diffs reviewable.

**Do NOT modify:** the FM engine (`FoundationModelsEngine`), `ConversationManager`/`HeartbeatManager` call sites (they stay engine-agnostic; Stage C does selection), `b0tApp`, `b0tBrain`, `b0tModules`.

**Verification commands** (repo root):
- Non-live unit tests: `swift test --package-path b0tKit --filter b0tCoreTests`
- Llama live tests (opt-in): `LIVE_LLAMA=1 swift test --package-path b0tKit --filter b0tLlamaLiveTests`
- App build: `xcodebuild build -project b0t.xcodeproj -scheme b0t -destination 'generic/platform=iOS Simulator'`

---

## Sub-stage B1 — XCFramework integration + `LlamaRuntime` (integration spike)

> **Spike note.** This sub-stage links a C library for the first time; exact C call signatures must be finalized against the *real* `include/llama.h` of the pinned build — the sequence below (from the verified research and `LibLlama.swift`) is the implementation guide, not guaranteed-verbatim code. The TDD gate is behavioural: a gated live test loads the test model and generates non-empty text. Do not hand-fabricate signatures you can't compile; read the linked header.

### Task B1.1: Add the XCFramework and `b0tLlama` target to `Package.swift`

**Files:**
- Modify: `b0tKit/Package.swift`

- [x] **Step 1: Pin the current xcframework release**

Find the latest `llama-b{N}-xcframework.zip` on `https://github.com/ggml-org/llama.cpp/releases` and compute its checksum:

```bash
swift package --package-path b0tKit compute-checksum llama-b9415-xcframework.zip
# or: shasum -a 256 llama-b9415-xcframework.zip
```

- [x] **Step 2: Add the binaryTarget, product, and target**

In `b0tKit/Package.swift`, add to `products`:

```swift
        .library(name: "b0tLlama", targets: ["b0tLlama"]),
```

Add to `targets` (use the build id + checksum from Step 1):

```swift
        .binaryTarget(
            name: "llama",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b9415/llama-b9415-xcframework.zip",
            checksum: "<sha256-from-step-1>"
        ),
        .target(
            name: "b0tLlama",
            dependencies: ["b0tCore", "llama"]
        ),
        .testTarget(
            name: "b0tLlamaLiveTests",
            dependencies: ["b0tLlama"]
        ),
```

- [x] **Step 3: Verify the package resolves and builds the empty target**

Add a placeholder `b0tKit/Sources/b0tLlama/Placeholder.swift`:

```swift
import llama
import b0tCore

// Placeholder — confirms b0tLlama links the llama xcframework and b0tCore.
enum B0tLlamaModule {}
```

Run: `swift build --package-path b0tKit --target b0tLlama`
Expected: builds; the `llama` module imports. If `import llama` fails, check the xcframework's module name (inspect the unzipped `.xcframework`'s modulemap) and adjust the import.

- [x] **Step 4: Commit**

```bash
git add b0tKit/Package.swift b0tKit/Sources/b0tLlama/Placeholder.swift
git commit -m "build(b0tLlama): add llama.cpp xcframework binaryTarget + b0tLlama target (Stage B)"
```

### Task B1.2: Define the `LlamaRuntime` public interface + error type

This is the b0t-owned surface every later task builds on. Define it fully now (signatures), implement the body in B1.3.

**Files:**
- Create: `b0tKit/Sources/b0tLlama/LlamaChatMessage.swift`
- Create: `b0tKit/Sources/b0tLlama/LlamaRuntime.swift`
- Delete: `b0tKit/Sources/b0tLlama/Placeholder.swift`

- [x] **Step 1: Create the message + error types**

`LlamaChatMessage.swift`:

```swift
import Foundation

/// A role-tagged message handed to `LlamaRuntime`. Roles map to chat-template
/// roles ("system", "user", "assistant").
public struct LlamaChatMessage: Sendable, Equatable {
    public let role: String
    public let content: String
    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

/// Errors from the llama.cpp runtime wrapper.
public enum LlamaRuntimeError: Error, Sendable, Equatable {
    case modelLoadFailed(path: String)
    case contextCreationFailed
    case templateApplyFailed
    case decodeFailed(code: Int32)
    case generationTimedOut
}
```

- [x] **Step 2: Declare the `LlamaRuntime` actor interface (bodies stubbed to `fatalError`)**

`LlamaRuntime.swift`:

```swift
import Foundation
import llama

/// Thin b0t-owned wrapper over the llama.cpp C API. Loads one GGUF model and
/// its context, applies the model's embedded chat template, and generates text
/// — optionally constrained by a GBNF grammar. One resident model per instance.
///
/// An `actor` so the non-Sendable C context pointers never cross threads
/// unsynchronised. Model/context are freed in `deinit`.
public actor LlamaRuntime {
    /// The model's trained context length (from GGUF metadata), used as the
    /// token-budget denominator by callers.
    public nonisolated let contextWindow: Int

    /// Loads `modelPath` and creates a context of `contextLength` tokens
    /// (clamped to the model's trained maximum).
    public init(modelPath: URL, contextLength: Int) throws { fatalError("B1.3") }

    /// Applies the model's embedded chat template to `messages`, tokenizes,
    /// and generates until EOG or `maxTokens`. If `grammar` is non-nil, a GBNF
    /// grammar sampler constrains output to it (root rule "root").
    public func generate(
        messages: [LlamaChatMessage],
        grammar: String?,
        maxTokens: Int
    ) async throws -> String { fatalError("B1.3") }
}
```

- [x] **Step 3: Build (compiles with stubs), delete placeholder, commit**

Run: `swift build --package-path b0tKit --target b0tLlama`
Expected: compiles (the `contextWindow` `let` will warn/err as uninitialised — give it a temporary `= 0` in a throwing init path or mark the init `fatalError` before the stored-property rule bites; if the compiler rejects the stub, set `self.contextWindow = 0` before `fatalError`). Resolve so it builds, then:

```bash
git rm b0tKit/Sources/b0tLlama/Placeholder.swift
git add b0tKit/Sources/b0tLlama/LlamaChatMessage.swift b0tKit/Sources/b0tLlama/LlamaRuntime.swift
git commit -m "feat(b0tLlama): LlamaRuntime + LlamaChatMessage interface (Stage B)"
```

### Task B1.3: Implement `LlamaRuntime` against the C API + gated smoke test

**Files:**
- Modify: `b0tKit/Sources/b0tLlama/LlamaRuntime.swift`
- Create: `b0tKit/Tests/b0tLlamaLiveTests/LlamaModelCache.swift`
- Create: `b0tKit/Tests/b0tLlamaLiveTests/LlamaRuntimeLiveTests.swift`

- [x] **Step 1: Write the gated smoke test first (it defines the behavioural target)**

`LlamaModelCache.swift`:

```swift
import Foundation
import XCTest

/// Downloads the SmolLM2-360M test model to a local cache on first use.
/// Skips (not fails) when LIVE_LLAMA != "1" so default `swift test` stays
/// offline and fast.
enum LlamaModelCache {
    static let modelURL = URL(
        string: "https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf"
    )!
    static var cacheFile: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("b0t-tests/models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("SmolLM2-360M-Instruct-Q4_K_M.gguf")
    }

    /// Returns the local model path, downloading once if absent. Throws
    /// `XCTSkip` when LIVE_LLAMA is unset.
    static func ensureModel() async throws -> URL {
        guard ProcessInfo.processInfo.environment["LIVE_LLAMA"] == "1" else {
            throw XCTSkip("LIVE_LLAMA != 1 — skipping llama live test")
        }
        let file = cacheFile
        if FileManager.default.fileExists(atPath: file.path) { return file }
        let (tmp, _) = try await URLSession.shared.download(from: modelURL)
        try FileManager.default.moveItem(at: tmp, to: file)
        return file
    }
}
```

`LlamaRuntimeLiveTests.swift`:

```swift
import XCTest
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
        XCTAssertGreaterThan(await runtime.contextWindow, 0)
    }
}
```

- [x] **Step 2: Run it to confirm it fails (hits the `fatalError` stub)**

Run: `LIVE_LLAMA=1 swift test --package-path b0tKit --filter b0tLlamaLiveTests/test_generatesNonEmptyText`
Expected: FAIL/crash at the `fatalError("B1.3")` stub (after the model downloads once).

- [x] **Step 3: Implement `LlamaRuntime` against `include/llama.h`**

Implement `init` and `generate` following the verified call sequence in the research grounding above, mirroring `examples/llama.swiftui/llama.cpp.swift/LibLlama.swift` from the pinned build. Required behaviours:
- `init`: `llama_backend_init()` (once); `llama_model_load_from_file` (throw `.modelLoadFailed` on null); set `contextWindow` from `llama_model_n_ctx_train(model)` clamped with `contextLength`; `llama_init_from_model` (throw `.contextCreationFailed` on null); cache the `vocab` via `llama_model_get_vocab`.
- `generate`: build a `[llama_chat_message]` from `messages`; get the template via `llama_model_chat_template(model, nil)`; `llama_chat_apply_template(...)` (grow buffer + retry if the return > buffer; throw `.templateApplyFailed` on negative); tokenize; build a sampler chain — **if `grammar != nil`, add `llama_sampler_init_grammar(vocab, grammar, "root")` first**, then temp + dist; decode loop with `llama_batch`/`llama_decode` (throw `.decodeFailed(code:)` on non-zero), `llama_sampler_sample`, stop on `llama_vocab_is_eog` or `maxTokens`; accumulate pieces via `llama_token_to_piece`; free the sampler chain.
- `deinit`: `llama_free(context)`, `llama_model_free(model)`. (`llama_backend_free()` is process-global; call it only if you reference-count instances — for one resident model, leaving the backend initialised is acceptable; document the choice.)

Pin exact signatures against the header at `https://raw.githubusercontent.com/ggml-org/llama.cpp/b9415/include/llama.h`. Handle Swift↔C string/array bridging with `withCString`/`UnsafeMutableBufferPointer` as `LibLlama.swift` does.

- [x] **Step 4: Run the smoke test to verify it passes**

Run: `LIVE_LLAMA=1 swift test --package-path b0tKit --filter b0tLlamaLiveTests/test_generatesNonEmptyText`
Expected: PASS — non-empty generation, `contextWindow > 0`.

- [x] **Step 5: Confirm non-live suite is unaffected**

Run: `swift test --package-path b0tKit --filter b0tCoreTests`
Expected: PASS (287). The live target is skipped without `LIVE_LLAMA`.

- [x] **Step 6: Commit**

```bash
git add b0tKit/Sources/b0tLlama/LlamaRuntime.swift b0tKit/Tests/b0tLlamaLiveTests/
git commit -m "feat(b0tLlama): implement LlamaRuntime over llama.cpp C API + gated smoke test (Stage B)"
```

---

## Sub-stage B2 — `StructuredOutput` grammar + shape hint (`b0tCore`, pure Swift)

### Task B2.1: Add `gbnfGrammar` + `jsonShapeHint` to `StructuredOutput`; generate grammars

**Files:**
- Create: `b0tKit/Sources/b0tCore/Decisions/StructuredOutput+Grammar.swift`
- Create: `b0tKit/Sources/b0tCore/Resources/Grammars/ConversationResponse.gbnf`, `TickDecision.gbnf`, `MemoryObservation.gbnf`, `RelationshipNote.gbnf`, `MoodTransition.gbnf`
- Modify: `b0tKit/Package.swift` (add `resources: [.process("Resources")]` to the `b0tCore` target)
- Test: `b0tKit/Tests/b0tCoreTests/StructuredOutputGrammarTests.swift`

- [ ] **Step 1: Generate the GBNF grammars offline (documented one-time step)**

For each decision type, write its JSON schema and convert it with llama.cpp's tool. Example for `ConversationResponse` (fields: `text: String`, `mood: MoodTag?` enum, `memoryObservations: [MemoryObservation]`):

```bash
# clone llama.cpp once for the converter (not a project dependency)
cat > /tmp/ConversationResponse.schema.json <<'JSON'
{
  "type": "object",
  "properties": {
    "text": { "type": "string" },
    "mood": { "type": ["string","null"], "enum": ["idle","speaking","thinking","surprised","sleepy","attentive","worried","delighted",null] },
    "memoryObservations": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "about": {"type":"string"}, "what": {"type":"string"},
          "importance": {"type":"string","enum":["low","medium","high"]}
        },
        "required": ["about","what","importance"]
      }
    }
  },
  "required": ["text","memoryObservations"]
}
JSON
python3 llama.cpp/examples/json_schema_to_grammar.py /tmp/ConversationResponse.schema.json \
  > b0tKit/Sources/b0tCore/Resources/Grammars/ConversationResponse.gbnf
```

Repeat for `TickDecision` (fields per `TickDecision.swift`), `MemoryObservation`, `RelationshipNote`, `MoodTransition`. Keep each schema's `required`/optionality matching the Swift type's optionals (e.g. `mood`/`organUsed` optional). Commit the schemas alongside the grammars (as `*.schema.json` in the same folder) so regeneration is reproducible.

- [ ] **Step 2: Write the failing unit test**

`StructuredOutputGrammarTests.swift`:

```swift
import Foundation
import XCTest

@testable import b0tCore

final class StructuredOutputGrammarTests: XCTestCase {
    func test_grammars_areNonEmptyAndRooted() {
        let types: [any StructuredOutput.Type] = [
            ConversationResponse.self, TickDecision.self, MemoryObservation.self,
            RelationshipNote.self, MoodTransition.self,
        ]
        for t in types {
            XCTAssertFalse(t.gbnfGrammar.isEmpty, "\(t) grammar empty")
            XCTAssertTrue(t.gbnfGrammar.contains("root"), "\(t) grammar lacks root rule")
            XCTAssertFalse(t.jsonShapeHint.isEmpty, "\(t) shape hint empty")
        }
    }
}
```

- [ ] **Step 3: Run it to confirm it fails**

Run: `swift test --package-path b0tKit --filter StructuredOutputGrammarTests`
Expected: FAIL — `gbnfGrammar`/`jsonShapeHint` are not members of `StructuredOutput`.

- [ ] **Step 4: Add the requirements + conformances + Package resources**

In `Package.swift`, change the `b0tCore` target to:

```swift
        .target(name: "b0tCore", dependencies: ["b0tBrain"], resources: [.process("Resources")]),
```

Create `StructuredOutput+Grammar.swift`:

```swift
import Foundation

extension StructuredOutput {
    /// GBNF grammar (root rule "root") constraining llama.cpp output to this
    /// type's JSON shape. Pre-generated offline from the committed schema —
    /// the xcframework does not expose json_schema_to_grammar. Regenerate when
    /// the type's fields change (see Resources/Grammars/*.schema.json).
    public static func loadGrammar(_ name: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "gbnf",
                                          subdirectory: "Grammars"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return text
    }
}

public extension StructuredOutput {
    static var gbnfGrammar: String { Self.loadGrammar(String(describing: Self.self)) }
}

// Per-type prompt shape hints (rendered into the prompt; llama.cpp does not
// inject the schema). Concise, human-readable field descriptions.
extension ConversationResponse {
    public static var jsonShapeHint: String {
        "JSON object: text (string), mood (one of idle|speaking|thinking|surprised|sleepy|attentive|worried|delighted, or omit), memoryObservations (array of {about, what, importance: low|medium|high})."
    }
}
extension TickDecision {
    public static var jsonShapeHint: String {
        "JSON object: observed (string), considered (array of strings), decided (string), why (string), acted (string), mood (optional mood label), organUsed (optional string), memoryObservations (array of {about, what, importance})."
    }
}
extension MemoryObservation {
    public static var jsonShapeHint: String { "JSON object: about (string), what (string), importance (low|medium|high)." }
}
extension RelationshipNote {
    public static var jsonShapeHint: String { "JSON object: name (string), relation (string), notes (string)." }
}
extension MoodTransition {
    public static var jsonShapeHint: String { "JSON object: from (mood label), to (mood label), why (string)." }
}
```

Add the `jsonShapeHint` requirement to the protocol in `StructuredOutput.swift`:

```swift
public protocol StructuredOutput: Generable, Codable, Sendable {
    static var gbnfGrammar: String { get }
    static var jsonShapeHint: String { get }
}
```

(`gbnfGrammar` has a default via the extension above; `jsonShapeHint` is provided per type.)

- [ ] **Step 5: Run the test to verify it passes**

Run: `swift test --package-path b0tKit --filter StructuredOutputGrammarTests`
Expected: PASS. Then run `swift test --package-path b0tKit --filter b0tCoreTests` → still 287+ green.

- [ ] **Step 6: Commit**

```bash
git add b0tKit/Package.swift b0tKit/Sources/b0tCore/Model/StructuredOutput.swift \
        b0tKit/Sources/b0tCore/Decisions/StructuredOutput+Grammar.swift \
        b0tKit/Sources/b0tCore/Resources/Grammars/ \
        b0tKit/Tests/b0tCoreTests/StructuredOutputGrammarTests.swift
git commit -m "feat(b0tCore): pre-generated GBNF grammars + shape hints on StructuredOutput (Stage B)"
```

---

## Sub-stage B3 — `LlamaEngine` (`InferenceEngine` conformer) + end-to-end

### Task B3.1: Implement `LlamaEngine` and an end-to-end gated live test

**Files:**
- Create: `b0tKit/Sources/b0tLlama/LlamaEngine.swift`
- Modify: `b0tKit/Tests/b0tLlamaLiveTests/LlamaRuntimeLiveTests.swift` (add e2e case)

- [ ] **Step 1: Write the failing end-to-end test**

Add to `LlamaRuntimeLiveTests`:

```swift
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
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `LIVE_LLAMA=1 swift test --package-path b0tKit --filter b0tLlamaLiveTests/test_llamaEngine_decodesTypedConversationResponse`
Expected: FAIL — `LlamaEngine` does not exist.

- [ ] **Step 3: Implement `LlamaEngine`**

`LlamaEngine.swift`:

```swift
import Foundation
import b0tBrain
import b0tCore

/// `InferenceEngine` backed by a local GGUF model via `LlamaRuntime`.
///
/// Stage B: no tools (`records` always empty). Structured output is enforced by
/// the type's pre-generated GBNF grammar and decoded from JSON via `Codable`.
public struct LlamaEngine: InferenceEngine {
    private let runtime: LlamaRuntime

    public var contextWindow: Int { get async { await runtime.contextWindow } }

    public init(modelPath: URL, contextLength: Int) throws {
        self.runtime = try LlamaRuntime(modelPath: modelPath, contextLength: contextLength)
    }

    public func generate<Output: StructuredOutput>(
        context: AssembledContext,
        generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord]) {
        // llama.cpp does not inject the schema, so describe the shape in-prompt.
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
            maxTokens: 512
        )
        guard let data = Self.firstJSONObject(in: raw)?.data(using: .utf8) else {
            throw InferenceEngineError.malformedGenerableOutput(
                underlyingDescription: "no JSON object in llama output: \(raw.prefix(200))")
        }
        do {
            let value = try JSONDecoder().decode(Output.self, from: data)
            return (value, [])
        } catch {
            throw InferenceEngineError.malformedGenerableOutput(
                underlyingDescription: String(describing: error))
        }
    }

    /// Extracts the first balanced `{...}` span — defensive against models that
    /// wrap JSON in prose despite the grammar (and against grammar-off fallback).
    static func firstJSONObject(in text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var idx = start
        while idx < text.endIndex {
            let c = text[idx]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(text[start...idx]) } }
            idx = text.index(after: idx)
        }
        return nil
    }
}
```

> **Note on `contextWindow`:** Stage A's `InferenceEngine` protocol does not yet declare `contextWindow` (that's the variable-budget work). `LlamaEngine` exposes it as a plain `async` property for now; Stage C adds it to the protocol and re-bases budgeting. If the compiler requires protocol conformance only, this extra property is harmless.

- [ ] **Step 4: Run the e2e test to verify it passes**

Run: `LIVE_LLAMA=1 swift test --package-path b0tKit --filter b0tLlamaLiveTests/test_llamaEngine_decodesTypedConversationResponse`
Expected: PASS — a `ConversationResponse` with non-empty `text` is decoded from grammar-constrained output.

> **If grammar sampling fails** (cf. issue #21571): first confirm via a `grammar: <ConversationResponse.gbnfGrammar>` call in the B1 smoke test. If `llama_sampler_init_grammar` errors against the pinned build, fall back to grammar-off generation + `firstJSONObject` + tolerant decode for Stage B, and file the grammar issue as a Stage C blocker. Record the decision in the commit body. Do NOT silently ship without structured-output enforcement — surface it.

- [ ] **Step 5: Full regression + app build**

Run: `swift test --package-path b0tKit` (non-live green), then `xcodebuild build -project b0t.xcodeproj -scheme b0t -destination 'generic/platform=iOS Simulator'` → BUILD SUCCEEDED (note: `b0tApp` does not yet link `b0tLlama` until Stage C wiring; this confirms no regression).

- [ ] **Step 6: Commit**

```bash
git add b0tKit/Sources/b0tLlama/LlamaEngine.swift b0tKit/Tests/b0tLlamaLiveTests/LlamaRuntimeLiveTests.swift
git commit -m "feat(b0tLlama): LlamaEngine — grammar-constrained typed output via llama.cpp (Stage B)"
```

### Task B3.2: Document the engine + update `b0tCore`/`b0tLlama` docs

**Files:**
- Create: `b0tKit/Sources/b0tLlama/CLAUDE.md`
- Modify: `b0tKit/Sources/b0tCore/CLAUDE.md` (note the grammar additions)

- [ ] **Step 1: Write `b0tLlama/CLAUDE.md`**

Document: the xcframework dependency + pinned build, `LlamaRuntime` (one resident model, applies embedded chat template, optional GBNF), `LlamaEngine` (InferenceEngine conformer, no tools in Stage B, GBNF+JSON decode), the gated `LIVE_LLAMA=1` test pattern + the cached SmolLM2 model, and the "no Swift/C++ interop — pure C" fact. Note Stage C will add capability detection, the download manager, and `identity/processor.md` selection.

- [ ] **Step 2: Update `b0tCore/CLAUDE.md`**

Add to the `StructuredOutput` line: "Stage B added `gbnfGrammar` (pre-generated, committed under `Resources/Grammars/`) and `jsonShapeHint` for the llama path."

- [ ] **Step 3: Commit**

```bash
git add b0tKit/Sources/b0tLlama/CLAUDE.md b0tKit/Sources/b0tCore/CLAUDE.md
git commit -m "docs(b0tLlama): document the llama engine + grammar additions (Stage B)"
```

---

## Self-review

**Spec coverage (`docs/specs/phase-2-inference-engine-abstraction.md`):**
- §3.1 `LlamaEngine` as `InferenceEngine` conformer — B3.1. ✓
- §3.2 structured-output parity via GBNF — refined to **pre-generated** grammars (B2.1) + grammar-constrained sampling + JSON decode (B3.1), per the verified xcframework limitation. ✓
- §3.3 engine-owned format layer — `LlamaRuntime` applies the GGUF-embedded chat template (B1.3). ✓
- §5 download/lifecycle — **only the test-model cache** (B1.3) is in scope; the production download manager + lifecycle are Stage C. ✓ (explicit)
- §6 tools on llama — **deferred** (no tool-capable test model; needs §14 Q6). `supportsTools` false. ✓ (explicit)
- §8 testing — gated `LIVE_LLAMA=1` live tests mirroring the existing `LIVE_TESTS` pattern; non-live suite stays green; app build checked. ✓

**Placeholder scan:** The only non-verbatim code is in the B1 spike (the C-interop body), which is explicitly a spike with a behavioural test gate and a linked authoritative header — not a vague "implement later." Every pure-Swift task (B2, B3) has exact code. The grammar files are generated by a real tool from exact committed schemas, not hand-faked. ✓

**Type consistency:** `LlamaRuntime` (init + `generate(messages:grammar:maxTokens:)` + `contextWindow`), `LlamaChatMessage(role:content:)`, `LlamaRuntimeError`, `LlamaEngine(modelPath:contextLength:)`, `StructuredOutput.gbnfGrammar`/`jsonShapeHint`, `InferenceEngineError.malformedGenerableOutput` are used consistently across B1–B3 and match the Stage-A as-built names (`AssembledContext`, `ToolCallRecord`, `InferenceEngine`). ✓

**Known risks called out in-plan:** issue #21571 grammar-sampler failures (B3.1 fallback + escalation), xcframework module-name verification (B1.1 Step 3), `contextWindow` not yet on the protocol (B3.1 note). None silently resolved.

**Out of scope (Stage C/later):** capability detection + default selection, user switching, `identity/processor.md` config, the production download manager + jetsam lifecycle + catalogue, variable-window budgeting on the protocol, the llama tool-call harness, and the production model lineup (§14 Q6).
```
