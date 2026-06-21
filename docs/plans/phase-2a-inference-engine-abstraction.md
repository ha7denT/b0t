# Stage A — Inference Engine Abstraction (pure refactor) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decouple `b0tCore`'s model seam from the Foundation Models `Generable` constraint and rename it to an engine-agnostic `InferenceEngine`, so that Stage B can add a llama.cpp engine as a pure addition — with zero behaviour change and all 279 existing tests still green.

**Architecture:** Introduce a `StructuredOutput` protocol (refines FM's `Generable`, adds `Codable`) that the decision types conform to. Rename `LanguageModelClient` → `InferenceEngine` and change its generic constraint from `Output: Generable` to `Output: StructuredOutput`. Keep `LiveLanguageModelClient`/`LanguageModelClient`/`StubLanguageModelClient` names alive as `typealias`es so `b0tApp` and existing tests compile untouched. Tools stay as FM `[any Tool]` for now — tool-descriptor decoupling is deferred to Stage B, where the llama engine actually needs it.

**Tech Stack:** Swift 6, SwiftPM (`b0tKit`), FoundationModels (system framework, iOS/macOS 26), XCTest.

**Scope note:** This is Stage A of the four-stage Phase 2 re-open (see `docs/specs/phase-2-inference-engine-abstraction.md`). Stages B (llama engine), C (download/lifecycle/catalogue), and D (Processor wiring) get their own plans once this lands and the §14 Q6 model lineup is validated on-device. `b0tBrain` and `b0tModules` are **not** touched by Stage A.

**Verification commands** (run from the repo root):
- Single test: `swift test --package-path b0tKit --filter <Suite>/<test>`
- Whole b0tCore suite: `swift test --package-path b0tKit --filter b0tCoreTests`
- Full package: `swift test --package-path b0tKit`

---

## File structure

**Create:**
- `b0tKit/Sources/b0tCore/Model/StructuredOutput.swift` — the engine-neutral output protocol.
- `b0tKit/Tests/b0tCoreTests/CodableRoundTripTests.swift` — JSON Codable round-trip for every decision type.
- `b0tKit/Tests/b0tCoreTests/StructuredOutputConformanceTests.swift` — compile-time + runtime conformance checks.

**Modify:**
- `b0tKit/Sources/b0tCore/Decisions/MoodTag.swift` — add `Codable`.
- `b0tKit/Sources/b0tCore/Decisions/Importance.swift` — add `Codable`.
- `b0tKit/Sources/b0tCore/Decisions/MemoryObservation.swift` — add `Codable`, `StructuredOutput`.
- `b0tKit/Sources/b0tCore/Decisions/ConversationResponse.swift` — add `Codable`, `StructuredOutput`.
- `b0tKit/Sources/b0tCore/Decisions/TickDecision.swift` — add `Codable`, `StructuredOutput`.
- `b0tKit/Sources/b0tCore/Decisions/RelationshipNote.swift` — add `Codable`, `StructuredOutput`.
- `b0tKit/Sources/b0tCore/Decisions/MoodTransition.swift` — add `Codable`, `StructuredOutput`.
- `b0tKit/Sources/b0tCore/Model/LanguageModelClient.swift` — rename protocol → `InferenceEngine`; add transition `typealias`es; change constraint to `StructuredOutput`; rename error enum.
- `b0tKit/Sources/b0tCore/Model/LiveLanguageModelClient.swift` — rename struct → `FoundationModelsEngine` + `typealias`; constraint change.
- `b0tKit/Sources/b0tCore/Model/StubLanguageModelClient.swift` — rename → `StubInferenceEngine` + `typealias`; constraint change.
- `b0tKit/Sources/b0tCore/CLAUDE.md` — document the seam.

**Do NOT modify:** `b0tApp` (typealiases keep it compiling), `b0tBrain`, `b0tModules`, any existing test file (they reference the typealiased names).

---

### Task 1: `Codable` on the leaf enums (`MoodTag`, `Importance`)

These are nested inside the decision structs, so they must be `Codable` before the structs can synthesise `Codable`. Both are `String`-raw enums, so conformance is free once declared.

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Decisions/MoodTag.swift`
- Modify: `b0tKit/Sources/b0tCore/Decisions/Importance.swift`
- Test: `b0tKit/Tests/b0tCoreTests/CodableRoundTripTests.swift` (create)

- [x] **Step 1: Write the failing test**

Create `b0tKit/Tests/b0tCoreTests/CodableRoundTripTests.swift`:

```swift
import Foundation
import XCTest

@testable import b0tCore

/// JSON Codable round-trip for every decision type. This is the path the
/// Stage B llama engine will use to decode grammar-constrained model output,
/// so the encode→decode identity must hold for all of them.
final class CodableRoundTripTests: XCTestCase {

    private func jsonRoundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func test_moodTag_codableRoundTrips() throws {
        for tag in MoodTag.allCases {
            XCTAssertEqual(try jsonRoundTrip(tag), tag)
        }
    }

    func test_importance_codableRoundTrips() throws {
        for value in Importance.allCases {
            XCTAssertEqual(try jsonRoundTrip(value), value)
        }
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --package-path b0tKit --filter CodableRoundTripTests`
Expected: FAIL — compile error, `MoodTag`/`Importance` do not conform to `Codable` (`Decodable`/`Encodable`).

- [x] **Step 3: Add `Codable` to both enums**

In `MoodTag.swift`, change the declaration line:

```swift
public enum MoodTag: String, Codable, Sendable, Equatable, CaseIterable {
```

In `Importance.swift`, change the declaration line:

```swift
public enum Importance: String, Codable, Sendable, Equatable, CaseIterable {
```

- [x] **Step 4: Run test to verify it passes**

Run: `swift test --package-path b0tKit --filter CodableRoundTripTests`
Expected: PASS (2 tests).

- [x] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tCore/Decisions/MoodTag.swift \
        b0tKit/Sources/b0tCore/Decisions/Importance.swift \
        b0tKit/Tests/b0tCoreTests/CodableRoundTripTests.swift
git commit -m "refactor(b0tCore): Codable on MoodTag and Importance (Stage A)"
```

---

### Task 2: `Codable` on `MemoryObservation`

`MemoryObservation` nests `Importance` (now `Codable`) and is itself nested in `ConversationResponse`/`TickDecision`, so it comes next. All stored properties (`String`, `String`, `Importance`) are `Codable`, so synthesis is automatic.

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Decisions/MemoryObservation.swift`
- Test: `b0tKit/Tests/b0tCoreTests/CodableRoundTripTests.swift`

- [x] **Step 1: Write the failing test**

Add to `CodableRoundTripTests`:

```swift
    func test_memoryObservation_codableRoundTrips() throws {
        let original = MemoryObservation(about: "Hayden", what: "likes coffee", importance: .high)
        XCTAssertEqual(try jsonRoundTrip(original), original)
    }
```

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --package-path b0tKit --filter CodableRoundTripTests/test_memoryObservation_codableRoundTrips`
Expected: FAIL — `MemoryObservation` does not conform to `Codable`.

- [x] **Step 3: Add `Codable`**

In `MemoryObservation.swift`, change the declaration line:

```swift
public struct MemoryObservation: Sendable, Equatable, Codable {
```

- [x] **Step 4: Run test to verify it passes**

Run: `swift test --package-path b0tKit --filter CodableRoundTripTests/test_memoryObservation_codableRoundTrips`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tCore/Decisions/MemoryObservation.swift \
        b0tKit/Tests/b0tCoreTests/CodableRoundTripTests.swift
git commit -m "refactor(b0tCore): Codable on MemoryObservation (Stage A)"
```

---

### Task 3: `Codable` on the four remaining decision types

`ConversationResponse`, `TickDecision`, `RelationshipNote`, `MoodTransition`. All their members are now `Codable` (`String`, `[String]`, `MoodTag?`, `[MemoryObservation]`, etc.), so synthesis is automatic.

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Decisions/ConversationResponse.swift`
- Modify: `b0tKit/Sources/b0tCore/Decisions/TickDecision.swift`
- Modify: `b0tKit/Sources/b0tCore/Decisions/RelationshipNote.swift`
- Modify: `b0tKit/Sources/b0tCore/Decisions/MoodTransition.swift`
- Test: `b0tKit/Tests/b0tCoreTests/CodableRoundTripTests.swift`

- [x] **Step 1: Write the failing tests**

Add to `CodableRoundTripTests`:

```swift
    func test_conversationResponse_codableRoundTrips() throws {
        let original = ConversationResponse(
            text: "hello",
            mood: .delighted,
            memoryObservations: [
                MemoryObservation(about: "Hayden", what: "likes coffee", importance: .medium)
            ]
        )
        XCTAssertEqual(try jsonRoundTrip(original), original)
    }

    func test_tickDecision_codableRoundTrips() throws {
        let original = TickDecision(
            observed: "afternoon",
            considered: ["pass", "glance_calendar"],
            decided: "pass",
            why: "nothing urgent",
            acted: "noted silently",
            mood: .attentive,
            organUsed: "calendar",
            memoryObservations: [MemoryObservation(about: "x", what: "y", importance: .low)]
        )
        XCTAssertEqual(try jsonRoundTrip(original), original)
    }

    func test_relationshipNote_codableRoundTrips() throws {
        let original = RelationshipNote(name: "Sam", relation: "spouse", notes: "likes coffee")
        XCTAssertEqual(try jsonRoundTrip(original), original)
    }

    func test_moodTransition_codableRoundTrips() throws {
        let original = MoodTransition(from: .idle, to: .delighted, why: "warm hello")
        XCTAssertEqual(try jsonRoundTrip(original), original)
    }
```

- [x] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path b0tKit --filter CodableRoundTripTests`
Expected: FAIL — the four types do not conform to `Codable`.

- [x] **Step 3: Add `Codable` to each declaration**

`ConversationResponse.swift`:

```swift
public struct ConversationResponse: Sendable, Equatable, Codable {
```

`TickDecision.swift`:

```swift
public struct TickDecision: Sendable, Equatable, Codable {
```

`RelationshipNote.swift` — change its declaration line to append `, Codable` (preserve the existing protocol list and `@Generable`).

`MoodTransition.swift` — change its declaration line to append `, Codable` (preserve the existing protocol list and `@Generable`).

- [x] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path b0tKit --filter CodableRoundTripTests`
Expected: PASS (all CodableRoundTrip tests).

- [x] **Step 5: Run the whole b0tCore suite to confirm no regression**

Run: `swift test --package-path b0tKit --filter b0tCoreTests`
Expected: PASS — existing `GenerableRoundTripTests` and all others still green (adding `Codable` does not affect the `@Generable` macro path).

- [x] **Step 6: Commit**

```bash
git add b0tKit/Sources/b0tCore/Decisions/ConversationResponse.swift \
        b0tKit/Sources/b0tCore/Decisions/TickDecision.swift \
        b0tKit/Sources/b0tCore/Decisions/RelationshipNote.swift \
        b0tKit/Sources/b0tCore/Decisions/MoodTransition.swift \
        b0tKit/Tests/b0tCoreTests/CodableRoundTripTests.swift
git commit -m "refactor(b0tCore): Codable on all decision types (Stage A)"
```

---

### Task 4: Introduce the `StructuredOutput` protocol

The engine-neutral output contract. It refines `Generable` (so the FM engine can still call `session.respond(generating:)`) and adds `Codable` (the path the Stage B llama engine will use). No `jsonSchema` member yet — that requirement is added in Stage B alongside the llama engine, so we don't author schemas we can't test.

**Files:**
- Create: `b0tKit/Sources/b0tCore/Model/StructuredOutput.swift`
- Test: `b0tKit/Tests/b0tCoreTests/StructuredOutputConformanceTests.swift` (create)

- [x] **Step 1: Write the failing test**

Create `b0tKit/Tests/b0tCoreTests/StructuredOutputConformanceTests.swift`:

```swift
import Foundation
import FoundationModels
import XCTest

@testable import b0tCore

/// Verifies the decision types passed to `InferenceEngine.generate` conform to
/// `StructuredOutput`. The generic helper only compiles if the conformance
/// exists, so this is a compile-time guarantee with a runtime assertion.
final class StructuredOutputConformanceTests: XCTestCase {

    private func accepts<T: StructuredOutput>(_ type: T.Type) -> Bool { true }

    func test_decisionTypes_areStructuredOutput() {
        XCTAssertTrue(accepts(ConversationResponse.self))
        XCTAssertTrue(accepts(TickDecision.self))
        XCTAssertTrue(accepts(MemoryObservation.self))
        XCTAssertTrue(accepts(RelationshipNote.self))
        XCTAssertTrue(accepts(MoodTransition.self))
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --package-path b0tKit --filter StructuredOutputConformanceTests`
Expected: FAIL — `StructuredOutput` is not defined; `accepts` won't compile.

- [x] **Step 3: Define the protocol and conform the types**

Create `b0tKit/Sources/b0tCore/Model/StructuredOutput.swift`:

```swift
import FoundationModels

/// The engine-neutral contract for a model's typed output.
///
/// It refines `Generable` so the Foundation Models engine can keep using the
/// macro path (`session.respond(generating:)`). It also requires `Codable` so
/// the Stage B llama.cpp engine can decode grammar-constrained JSON output to
/// the same type. The two paths produce the same Swift value; the engine
/// chooses how to populate it.
///
/// Stage B adds a `static var jsonSchema` requirement here (used to derive a
/// GBNF grammar and a prompt-side description); it is intentionally absent now
/// so we don't author schemas ahead of the engine that consumes them.
public protocol StructuredOutput: Generable, Codable, Sendable {}

extension ConversationResponse: StructuredOutput {}
extension TickDecision: StructuredOutput {}
extension MemoryObservation: StructuredOutput {}
extension RelationshipNote: StructuredOutput {}
extension MoodTransition: StructuredOutput {}
```

- [x] **Step 4: Run test to verify it passes**

Run: `swift test --package-path b0tKit --filter StructuredOutputConformanceTests`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tCore/Model/StructuredOutput.swift \
        b0tKit/Tests/b0tCoreTests/StructuredOutputConformanceTests.swift
git commit -m "feat(b0tCore): StructuredOutput protocol over the decision types (Stage A)"
```

---

### Task 5: Rename `LanguageModelClient` → `InferenceEngine`; constraint → `StructuredOutput`

Rename the protocol and its error enum, add transition `typealias`es so existing call sites (`b0tApp`, tests) keep compiling, and change the generic constraint from `Output: Generable` to `Output: StructuredOutput`.

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Model/LanguageModelClient.swift`

- [x] **Step 1: Edit the protocol file**

Replace the body of `b0tKit/Sources/b0tCore/Model/LanguageModelClient.swift` (keep the file name) with:

```swift
import Foundation
import FoundationModels
import b0tBrain

/// The seam through which `b0tCore` talks to a language model engine.
///
/// Engine-agnostic as of the 2026-05-29 amendment (ADR-0012). Conformers:
/// `FoundationModelsEngine` (Apple `LanguageModelSession`) and, from Stage B,
/// a llama.cpp-backed engine. Production code is identical against either;
/// tests use `StubInferenceEngine`.
///
/// `generate` returns `(Output, [ToolCallRecord])`. The records capture tool
/// invocations during generation. `Output` is `StructuredOutput` (refines
/// `Generable`, adds `Codable`) so both engines can populate the same type.
public protocol InferenceEngine: Sendable {
    func generate<Output: StructuredOutput>(
        context: AssembledContext,
        generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord])
}

/// Transition alias — existing call sites in `b0tApp` and tests refer to
/// `LanguageModelClient`. Remove in a later cleanup once references migrate.
public typealias LanguageModelClient = InferenceEngine

/// Errors surfaced by any `InferenceEngine` implementation.
///
/// `modelUnavailable` is raised by `FoundationModelsEngine` at init time when
/// `SystemLanguageModel.default.isAvailable == false`.
///
/// `exceededContextWindowSize` carries the assembler's pre-call estimate so the
/// graduated fallback in `ContextAssembler` can log which budget level fired.
public enum InferenceEngineError: Error, Sendable, Equatable {
    case modelUnavailable
    case exceededContextWindowSize(estimatedTokens: Int)
    case sessionFailed(underlyingDescription: String)
    case malformedGenerableOutput(underlyingDescription: String)
}

/// Transition alias for the renamed error enum.
public typealias LanguageModelClientError = InferenceEngineError
```

- [x] **Step 2: Run the full package to verify it still builds and passes**

Run: `swift test --package-path b0tKit`
Expected: PASS — `LiveLanguageModelClient` and `StubLanguageModelClient` still satisfy the protocol (their `generate<Output: Generable>` signatures are about to mismatch the new `StructuredOutput` constraint; if the compiler flags this here, it is fixed in Tasks 6–7). If a compile error appears in `LiveLanguageModelClient`/`StubLanguageModelClient`, proceed to Task 6 before re-running.

> Note: Tasks 5–7 form one compiling unit (the conformers must match the renamed protocol). Commit at the end of Task 7. This step's "expected" is the compile error that Tasks 6–7 resolve — do not commit a broken build.

- [x] **Step 3: (No commit yet — see Task 7.)**

---

### Task 6: Update `FoundationModelsEngine` (was `LiveLanguageModelClient`)

Rename the struct, add a `typealias` so `b0tApp` (which constructs `LiveLanguageModelClient()`) compiles untouched, and widen the generic constraint to `StructuredOutput`. The body is unchanged — `Output` is still `Generable` (because `StructuredOutput: Generable`), so `session.respond(generating:)` still compiles.

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Model/LiveLanguageModelClient.swift`

- [x] **Step 1: Rename the type and add the alias**

In `LiveLanguageModelClient.swift`, change the declaration:

```swift
public struct FoundationModelsEngine: InferenceEngine {
```

Immediately after the closing brace of the struct (end of file), add:

```swift

/// Transition alias — `b0tApp` constructs `LiveLanguageModelClient()`.
public typealias LiveLanguageModelClient = FoundationModelsEngine
```

- [x] **Step 2: Widen the generic constraint and update the error type**

In the same file, change the `generate` signature:

```swift
    public func generate<Output: StructuredOutput>(
        context: AssembledContext,
        generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord]) {
```

The `catch` block throws `LanguageModelClientError.*` cases — these still resolve via the `typealias`, so no change is required there. (Leave the body otherwise untouched.)

- [x] **Step 3: (No commit yet — see Task 7.)**

Run: `swift build --package-path b0tKit`
Expected: `b0tCore` compiles (the stub is fixed in Task 7; if the stub is the only remaining error, proceed).

---

### Task 7: Update `StubInferenceEngine` (was `StubLanguageModelClient`)

Rename the test seam, add a `typealias` so existing tests compile untouched, and widen the constraint. The handler closure keeps `any Generable.Type` (callers pass `Generable` types; `StructuredOutput` refines `Generable`, so the cast in the body is unchanged).

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Model/StubLanguageModelClient.swift`

- [x] **Step 1: Rename the type, add the alias, widen the constraint**

In `StubLanguageModelClient.swift`, change the struct declaration:

```swift
public struct StubInferenceEngine: InferenceEngine {
```

Change the `generate` signature:

```swift
    public func generate<Output: StructuredOutput>(
        context: AssembledContext,
        generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord]) {
```

The body uses `value as? Output` and throws `LanguageModelClientError.malformedGenerableOutput` — both still compile (`Output` is `StructuredOutput`; the error name resolves via `typealias`). Leave the body otherwise unchanged.

At the end of the file, add:

```swift

/// Transition alias — existing tests construct `StubLanguageModelClient(handler:)`.
public typealias StubLanguageModelClient = StubInferenceEngine
```

- [x] **Step 2: Run the full package to verify the whole refactor builds and passes**

Run: `swift test --package-path b0tKit`
Expected: PASS — all 279 existing tests green plus the new Codable/conformance tests. No behaviour change.

- [x] **Step 3: Commit the protocol rename + conformers together**

```bash
git add b0tKit/Sources/b0tCore/Model/LanguageModelClient.swift \
        b0tKit/Sources/b0tCore/Model/LiveLanguageModelClient.swift \
        b0tKit/Sources/b0tCore/Model/StubLanguageModelClient.swift
git commit -m "refactor(b0tCore): rename LanguageModelClient → InferenceEngine; constraint → StructuredOutput (Stage A)

Transition typealiases keep b0tApp and existing tests compiling. FM engine
renamed FoundationModelsEngine; stub renamed StubInferenceEngine. No behaviour
change — Output is still Generable via StructuredOutput's refinement."
```

---

### Task 8: Document the seam in `b0tCore/CLAUDE.md`

Reflect the rename and the engine-agnostic intent so future tasks (Stage B) start from the right model. Per the project DoD, update the doc when a change affects how future work is approached.

**Files:**
- Modify: `b0tKit/Sources/b0tCore/CLAUDE.md`

- [x] **Step 1: Update the heading and the client bullet**

In `b0tKit/Sources/b0tCore/CLAUDE.md`, change the first line from:

```markdown
# b0tCore

The Foundation Models loop. Owns the lifecycle of `LanguageModelSession` instances, the `ContextAssembler`, and the `@Generable` decision types that the model returns.
```

to:

```markdown
# b0tCore

The inference loop. Engine-agnostic as of ADR-0012: an `InferenceEngine` protocol with `FoundationModelsEngine` (Apple `LanguageModelSession`) as the only conformer today, and a llama.cpp engine arriving in Stage B. Owns the `ContextAssembler` and the decision types the model returns. Decision types are `@Generable` (FM path) **and** `Codable` (`StructuredOutput`, llama path).
```

Then update the `LanguageModelClient` bullet under "Public API contracts" to read:

```markdown
- `InferenceEngine` protocol (was `LanguageModelClient`, kept as a `typealias`); `generate<Output: StructuredOutput>(context:generating:)` returns `(Output, [ToolCallRecord])`. Conformers: `FoundationModelsEngine` (was `LiveLanguageModelClient`, aliased) wraps `LanguageModelSession`; `StubInferenceEngine` (was `StubLanguageModelClient`, aliased) is the test seam. `StructuredOutput` refines `Generable` and adds `Codable`; Stage B adds a `jsonSchema` requirement for schema→GBNF. Tool-descriptor decoupling is deferred to Stage B.
```

- [x] **Step 2: Commit**

```bash
git add b0tKit/Sources/b0tCore/CLAUDE.md
git commit -m "docs(b0tCore): document the InferenceEngine seam (Stage A)"
```

---

## Self-review

**Spec coverage (against `docs/specs/phase-2-inference-engine-abstraction.md`):**
- §3.1 `InferenceEngine` protocol — Tasks 5–7. ✓ (Tools left as FM `[any Tool]`; §3.4 tool-descriptor decoupling explicitly deferred to Stage B, stated in the plan header and Task 8.)
- §3.2 `StructuredDecodable`/output parity — Tasks 1–4 introduce `StructuredOutput` (Generable + Codable). The `jsonSchema`/GBNF half is Stage B by design (noted in Task 4 and the protocol doc-comment). ✓ for Stage A's portion.
- §8 staging — this plan is Stage A only; B/C/D deferred with rationale in the header. ✓
- §8 testing — existing 279 tests are the regression net (Task 3 Step 5, Task 7 Step 2); new Codable + conformance tests added; `StubInferenceEngine` generalised (Task 7). ✓

**Placeholder scan:** No "TBD"/"add error handling"/"similar to" — every code step shows the exact code or the exact declaration-line change. The one deliberate cross-task build gap (Tasks 5–7) is called out explicitly with a single commit at Task 7. ✓

**Type consistency:** `InferenceEngine`, `StructuredOutput`, `FoundationModelsEngine`, `StubInferenceEngine`, `InferenceEngineError` are used identically across Tasks 4–8; transition `typealias`es (`LanguageModelClient`, `LiveLanguageModelClient`, `StubLanguageModelClient`, `LanguageModelClientError`) preserve every existing reference in `b0tApp` and the test suite. The `generate<Output: StructuredOutput>` signature matches across the protocol (Task 5) and both conformers (Tasks 6–7). ✓

**Out of scope (carried to later Stage plans):** the `jsonSchema`/schema→GBNF requirement, tool-descriptor decoupling, `InferenceRequest` rename of `AssembledContext`, variable context-window budgeting, `EngineCapabilities`, and the `modelNotDownloaded`/`insufficientStorage` error cases all land in Stage B/C, not here.
```
