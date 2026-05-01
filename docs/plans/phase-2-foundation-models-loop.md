# Phase 2 — Foundation Models Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up `b0tCore` — the Foundation Models loop on top of Phase 1's markdown brain — meeting PRD §4 Phase 2 acceptance: a debug-only SwiftUI surface and an XCTest harness can hold a conversation with the production default-bot and fire heartbeat ticks that write OpenClaw-format journal entries.

**Architecture:** Walking-skeleton vertical slices. Slice 1 produces a stub-only end-to-end loop on day one (chat field → `ConversationManager` → `StubLanguageModelClient` → echo reply). Subsequent slices thicken the loop one component at a time: real Apple Foundation Models client, `ContextAssembler`, `Executor` with memory writes, `JournalWriter`, heartbeat skeleton, `schedule.md` parsing, missed-beat detection, `BGAppRefreshTask`, `TimeAwarenessTool`, polish + integration tests. The model layer is abstracted behind a `LanguageModelClient` protocol so most behaviour is testable without the real model.

**Tech Stack:**
- Swift 6.0+, iOS 26 deployment target (per Phase 0 / `project.yml`).
- `FoundationModels` framework (system-provided in iOS 26) — `LanguageModelSession`, `Generable`, `Tool`, `SystemLanguageModel.default.availability`.
- `BackgroundTasks` framework (system-provided) — `BGTaskScheduler`, `BGAppRefreshTaskRequest`.
- `b0tBrain` (Phase 1) — `BotStore`, `Bot`, `BotFile`, `Frontmatter`.
- XCTest (matches Phase 1 test convention).
- No new third-party dependencies.

**Spec:** `docs/specs/phase-2-foundation-models-loop.md` (approved 2026-05-01) is the source of truth for behaviour. This plan sequences the implementation; consult the spec when in doubt.

**Conventions used in this plan:**
- `**[CC]**` marks a Claude-Code-executable step.
- `**[VERIFY]**` marks a verification step — run a command, check output, do not move on if it fails.
- Tasks are TDD-shaped: failing test → minimal implementation → passing test → commit. Each task is a single atomic commit.
- Walking-skeleton discipline: every slice ends with everything compiling, all tests green, and the end-to-end loop demonstrably working at that slice's level of sophistication.

**Reference docs to consult during execution:**
- `docs/specs/phase-2-foundation-models-loop.md` — the design contract
- `docs/prd.md` §3.3, §3.4, §4 Phase 2, §5.2, §5.6 — REQUIRED constraints
- `docs/design_document.md` §5.4 — OpenClaw journal format (note: doc PR pending to align this with decision (i))
- `docs/decisions/0001-on-device-only.md` — privacy posture
- `docs/decisions/0002-markdown-as-source-of-truth.md` — why brain owns state
- `docs/references/voice-and-copy-guide.md` — for any user-facing string in `DebugBrainView` or error surfaces
- `b0tKit/Sources/b0tBrain/CLAUDE.md` — Phase 1 module-local reference
- `default-bot/heartbeat/{schedule,actions}.md` — concrete frontmatter shapes the parser must accept

---

## File Structure (what this phase creates/modifies)

**Creates** (under `b0tKit/Sources/b0tCore/`):

```
b0tCore/
├── ConversationManager.swift          // actor — user-turn flow
├── HeartbeatManager.swift             // actor — tick flow + BGTask
├── Schedule/
│   ├── HeartbeatSchedule.swift
│   ├── EventTriggerKind.swift
│   ├── HeartbeatScheduler.swift       // protocol + LiveBGTaskScheduler
│   └── MissedBeatDetector.swift
├── Model/
│   ├── LanguageModelClient.swift      // protocol + LanguageModelClientError
│   ├── LiveLanguageModelClient.swift  // wraps Apple LanguageModelSession
│   └── StubLanguageModelClient.swift  // @testable visible
├── Context/
│   ├── ContextAssembler.swift
│   ├── AssembledContext.swift
│   ├── AssemblyMode.swift
│   ├── TokenBudget.swift
│   └── TokenEstimator.swift
├── Decisions/                         // @Generable types
│   ├── ConversationResponse.swift
│   ├── TickDecision.swift
│   ├── MemoryObservation.swift
│   ├── RelationshipNote.swift
│   ├── MoodTransition.swift
│   ├── MoodTag.swift
│   └── Importance.swift
├── Apply/
│   ├── Executor.swift
│   ├── StateDelta.swift
│   ├── JournalWriter.swift
│   └── EntryKind.swift
├── Tools/
│   ├── TimeAwarenessTool.swift
│   └── TimeOfDay.swift
├── Support/
│   ├── Clock.swift                    // protocol + SystemClock + TestClock
│   └── TickResult.swift               // enum decided/suppressed/errored
└── CLAUDE.md                          // refreshed at end of phase to as-built
```

**Creates** (under `b0tKit/Tests/b0tCoreTests/`):

```
b0tCoreTests/
├── ContextAssemblerTests.swift
├── ExecutorTests.swift
├── JournalWriterTests.swift
├── ConversationManagerTests.swift
├── HeartbeatManagerTests.swift
├── HeartbeatScheduleTests.swift
├── MissedBeatDetectorTests.swift
├── TimeAwarenessToolTests.swift
├── GenerableRoundTripTests.swift
├── StubLanguageModelClientTests.swift
└── Fixtures/
    ├── canonical-bot/                 // copy of Phase 1 canonical-bot
    ├── journal-with-gaps/
    │   └── 2026-05-01.md
    ├── quiet-hours-bot/
    │   ├── heartbeat/schedule.md      // quiet hours covering "now"
    │   └── (other minimum files)
    └── full-budget-bot/
        ├── identity/{core,principles}.md       // intentionally large
        └── (other minimum files)
```

**Creates** (under `b0tKit/Tests/b0tCoreIntegrationTests/`):

```
b0tCoreIntegrationTests/
├── LiveModelConversationTest.swift
└── LiveModelTickTest.swift
```

**Creates** (under `b0tApp/Sources/Debug/`):

```
Debug/
└── DebugBrainView.swift               // DEBUG-only chat + journal-tail + "fire heartbeat" button
```

**Modifies:**

- `b0tKit/Package.swift` — add `b0tCoreIntegrationTests` test target; add `Fixtures` resource declaration to `b0tCoreTests`.
- `b0tKit/Sources/b0tCore/b0tCorePlaceholder.swift` — delete (replaced by real types after Task 1's tombstone).
- `b0tKit/Tests/b0tCoreTests/b0tCoreTests.swift` — delete (replaced by real tests).
- `project.yml` — add `BGTaskSchedulerPermittedIdentifiers` to the `b0t` target's `INFOPLIST_KEY_*` settings; regenerate `b0t.xcodeproj` after edit.
- `b0tApp/Sources/App/b0tApp.swift` — register `HeartbeatManager.register()` at launch; pass bot/store through to `ContentView` unchanged (already does this).
- `b0tApp/Sources/App/ContentView.swift` — add `#if DEBUG` button that opens `DebugBrainView` as a sheet.
- `b0tKit/Sources/b0tCore/CLAUDE.md` — refresh at end of phase to as-built API.
- `docs/IMPLEMENTATION.md` — advance Phase 2 → complete, current state → Phase 3.

---

## Slice 1 — Hello loop (stub model, end-to-end)

Goal of this slice: by end of Task 5, a developer can launch the app in simulator (DEBUG), tap a "debug brain" entry point, type a message, and see a canned echo reply. No Foundation Models, no markdown reads — just the wiring that proves the loop's shape.

### Task 1: Scaffold `b0tCore` module — delete placeholders, add directory tree

**Files:**
- Modify: `b0tKit/Package.swift`
- Delete: `b0tKit/Sources/b0tCore/b0tCorePlaceholder.swift`
- Delete: `b0tKit/Tests/b0tCoreTests/b0tCoreTests.swift`
- Create: `b0tKit/Sources/b0tCore/_Tombstone.swift` (temporary, deleted in Task 2)

**Why first:** Every later task creates files inside `b0tCore/`. Removing the placeholder and laying out the empty directory tree keeps subsequent tasks focused on real code. The integration test target needs to be declared before Slice 10 references it.

- [ ] **Step 1.1 [CC]: Update `Package.swift` to add the integration test target and fixtures resource**

Replace the contents of `/Users/haydentoppeross/development/b0t/b0tKit/Package.swift` with:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "b0tKit",
    platforms: [
        .iOS("26.0")
    ],
    products: [
        .library(name: "b0tCore", targets: ["b0tCore"]),
        .library(name: "b0tBrain", targets: ["b0tBrain"]),
        .library(name: "b0tSkills", targets: ["b0tSkills"]),
        .library(name: "b0tFace", targets: ["b0tFace"]),
        .library(name: "b0tAudio", targets: ["b0tAudio"]),
        .library(name: "b0tDesign", targets: ["b0tDesign"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0")
    ],
    targets: [
        .target(name: "b0tCore", dependencies: ["b0tBrain"]),
        .target(
            name: "b0tBrain",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ]
        ),
        .target(name: "b0tSkills", dependencies: ["b0tBrain"]),
        .target(name: "b0tFace", dependencies: ["b0tDesign"]),
        .target(name: "b0tAudio"),
        .target(name: "b0tDesign"),

        .testTarget(
            name: "b0tCoreTests",
            dependencies: ["b0tCore"],
            resources: [
                .copy("Fixtures")
            ]
        ),
        .testTarget(
            name: "b0tCoreIntegrationTests",
            dependencies: ["b0tCore"]
        ),
        .testTarget(
            name: "b0tBrainTests",
            dependencies: ["b0tBrain"],
            resources: [
                .copy("Fixtures")
            ]
        ),
        .testTarget(name: "b0tSkillsTests", dependencies: ["b0tSkills"]),
        .testTarget(name: "b0tFaceTests", dependencies: ["b0tFace"]),
        .testTarget(name: "b0tAudioTests", dependencies: ["b0tAudio"]),
        .testTarget(name: "b0tDesignTests", dependencies: ["b0tDesign"]),
    ],
    swiftLanguageModes: [.v6]
)
```

- [ ] **Step 1.2 [CC]: Delete the placeholder source and test**

```bash
cd /Users/haydentoppeross/development/b0t
rm b0tKit/Sources/b0tCore/b0tCorePlaceholder.swift
rm b0tKit/Tests/b0tCoreTests/b0tCoreTests.swift
```

- [ ] **Step 1.3 [CC]: Create the directory tree**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit/Sources/b0tCore
mkdir -p Schedule Model Context Decisions Apply Tools Support
cd /Users/haydentoppeross/development/b0t/b0tKit/Tests
mkdir -p b0tCoreTests/Fixtures b0tCoreIntegrationTests
mkdir -p b0tCoreTests/Fixtures/journal-with-gaps b0tCoreTests/Fixtures/quiet-hours-bot/heartbeat b0tCoreTests/Fixtures/full-budget-bot/identity b0tCoreTests/Fixtures/full-budget-bot/memory b0tCoreTests/Fixtures/full-budget-bot/heartbeat
cd /Users/haydentoppeross/development/b0t/b0tApp/Sources
mkdir -p Debug
```

- [ ] **Step 1.4 [CC]: Add a tombstone source so the `b0tCore` target still has at least one file**

`b0tKit/Sources/b0tCore/_Tombstone.swift`:

```swift
// Temporary file to keep b0tCore compiling between placeholder removal
// and the first real type. Deleted in Task 2.
internal enum _Tombstone {}
```

- [ ] **Step 1.5 [CC]: Add a tombstone source for `b0tCoreIntegrationTests`**

`b0tKit/Tests/b0tCoreIntegrationTests/_Tombstone.swift`:

```swift
// Temporary file. Real integration tests land in Slice 10.
import XCTest

final class _IntegrationTombstoneTests: XCTestCase {
    func test_targetCompiles() {}
}
```

- [ ] **Step 1.6 [CC]: Copy the canonical-bot fixture from Phase 1 into the b0tCoreTests fixtures**

```bash
cp -R /Users/haydentoppeross/development/b0t/b0tKit/Tests/b0tBrainTests/Fixtures/canonical-bot \
      /Users/haydentoppeross/development/b0t/b0tKit/Tests/b0tCoreTests/Fixtures/canonical-bot
```

- [ ] **Step 1.7 [VERIFY]: Build and run all tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift build 2>&1 | tail -20
swift test --no-parallel 2>&1 | tail -20
```

Expected: build succeeds with no warnings. `b0tCoreTests` reports zero tests; `b0tCoreIntegrationTests` reports one passing tombstone test. Phase 1 b0tBrainTests still all pass (78 tests).

- [ ] **Step 1.8 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Package.swift \
        b0tKit/Sources/b0tCore/ \
        b0tKit/Tests/b0tCoreTests/ \
        b0tKit/Tests/b0tCoreIntegrationTests/ \
        b0tApp/Sources/Debug/
git commit -m "feat(b0tCore): scaffold module directory tree, add integration test target

Removes the b0tCore placeholder source and test, lays out the directory
tree for the Phase 2 walking-skeleton slices, and adds a separate
b0tCoreIntegrationTests target for the gated live-FM integration tests
that land in Slice 10. Copies the canonical-bot fixture from Phase 1
for reuse by ContextAssembler and JournalWriter tests."
```

---

### Task 2: `LanguageModelClient` protocol + `LanguageModelClientError` + skeleton `ConversationResponse`

**Files:**
- Create: `b0tKit/Sources/b0tCore/Model/LanguageModelClient.swift`
- Create: `b0tKit/Sources/b0tCore/Decisions/ConversationResponse.swift`
- Create: `b0tKit/Tests/b0tCoreTests/StubLanguageModelClientTests.swift` (test file scaffolding only — real test in Task 3)
- Delete: `b0tKit/Sources/b0tCore/_Tombstone.swift`

**Why now:** The protocol is the seam every other task in this slice depends on. Defining it before any implementation pins the contract.

- [ ] **Step 2.1 [CC]: Delete the tombstone**

```bash
rm /Users/haydentoppeross/development/b0t/b0tKit/Sources/b0tCore/_Tombstone.swift
```

- [ ] **Step 2.2 [CC]: Write the skeleton `ConversationResponse`**

`b0tKit/Sources/b0tCore/Decisions/ConversationResponse.swift`:

```swift
import Foundation
import FoundationModels

/// The model's output for a user conversation turn.
///
/// Phase 2 slice 1 ships only the `text` field; slice 3 adds `mood` and
/// `memoryObservations`. The `@Generable` macro tells Foundation Models
/// how to produce a typed value of this shape from the model.
@Generable
public struct ConversationResponse: Sendable, Equatable {
    @Guide(description: "The reply the b0t says to the user.")
    public let text: String

    public init(text: String) {
        self.text = text
    }
}
```

- [ ] **Step 2.3 [CC]: Write `LanguageModelClient` protocol and error type**

`b0tKit/Sources/b0tCore/Model/LanguageModelClient.swift`:

```swift
import Foundation
import FoundationModels

/// The seam through which `b0tCore` talks to a language model.
///
/// Two implementations exist: `LiveLanguageModelClient` (wraps Apple's
/// `LanguageModelSession`) and `StubLanguageModelClient` (test-target visible).
/// Production code is identical against either; tests shape the stub's
/// outputs per case. See `docs/specs/phase-2-foundation-models-loop.md` §5.3.
public protocol LanguageModelClient: Sendable {
    func generate<Output: Generable>(
        context: AssembledContext,
        generating outputType: Output.Type
    ) async throws -> Output
}

/// Errors surfaced by any `LanguageModelClient` implementation.
///
/// `modelUnavailable` is raised by `LiveLanguageModelClient` at init time when
/// `SystemLanguageModel.default.isAvailable == false` (Apple Intelligence
/// disabled, device ineligible, model not yet downloaded, etc.).
///
/// `exceededContextWindowSize` carries the assembler's pre-call estimate so
/// the graduated fallback in `ContextAssembler` (spec §7.4) can log which
/// budget level triggered the fallback.
public enum LanguageModelClientError: Error, Sendable, Equatable {
    case modelUnavailable
    case exceededContextWindowSize(estimatedTokens: Int)
    case sessionFailed(underlyingDescription: String)
    case malformedGenerableOutput(underlyingDescription: String)
}
```

- [ ] **Step 2.4 [CC]: Add a placeholder `AssembledContext` so the protocol compiles**

The real type lands in Task 6. Create a minimal stand-in that we will overwrite.

`b0tKit/Sources/b0tCore/Context/AssembledContext.swift`:

```swift
import Foundation
import FoundationModels

/// Phase 2 slice 1 placeholder.
///
/// Slice 2 (Task 6) replaces this with the full struct (system instructions,
/// user prompt, tools array, token budget, loaded files). The intermediate
/// shape exists only so `LanguageModelClient` compiles in slice 1.
public struct AssembledContext: Sendable {
    public let userPrompt: String
    public let tools: [any Tool]

    public init(userPrompt: String, tools: [any Tool] = []) {
        self.userPrompt = userPrompt
        self.tools = tools
    }
}
```

- [ ] **Step 2.5 [VERIFY]: Build the package**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift build 2>&1 | tail -20
```

Expected: `b0tCore` compiles. No warnings. If `import FoundationModels` fails, confirm the deployment target in `Package.swift` is `.iOS("26.0")` and Xcode 26+ is installed.

- [ ] **Step 2.6 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/
git commit -m "feat(b0tCore): LanguageModelClient protocol + skeleton ConversationResponse

Defines the seam through which b0tCore talks to a language model — protocol
plus error taxonomy (modelUnavailable, exceededContextWindowSize, sessionFailed,
malformedGenerableOutput). Ships a one-field skeleton ConversationResponse
(@Generable, just text) and a placeholder AssembledContext that Task 6
replaces with the real struct. See spec §5.3, §6."
```

---

### Task 3: `StubLanguageModelClient` + tests

**Files:**
- Create: `b0tKit/Sources/b0tCore/Model/StubLanguageModelClient.swift`
- Create: `b0tKit/Tests/b0tCoreTests/StubLanguageModelClientTests.swift` (replace scaffolding from Task 2)

**Why now:** The stub is the test seam every later test relies on. Building and testing it standalone means Slice 2+ can use it confidently.

- [ ] **Step 3.1 [CC]: Write the failing test**

`b0tKit/Tests/b0tCoreTests/StubLanguageModelClientTests.swift`:

```swift
import XCTest
import FoundationModels
@testable import b0tCore

final class StubLanguageModelClientTests: XCTestCase {
    func test_returnsCannedConversationResponse() async throws {
        let stub = StubLanguageModelClient { context, outputType in
            XCTAssertEqual(context.userPrompt, "hi")
            XCTAssert(outputType == ConversationResponse.self)
            return ConversationResponse(text: "echo: hi")
        }
        let context = AssembledContext(userPrompt: "hi")
        let response: ConversationResponse = try await stub.generate(
            context: context,
            generating: ConversationResponse.self
        )
        XCTAssertEqual(response.text, "echo: hi")
    }

    func test_throwsWhenHandlerReturnsWrongType() async {
        // Stub's handler returns a String when the test asks for ConversationResponse.
        // The stub must surface this as malformedGenerableOutput rather than crash.
        let stub = StubLanguageModelClient { _, _ in
            // Return a String — wrong type relative to the request below.
            return "not a ConversationResponse" as Any
        }
        do {
            let _: ConversationResponse = try await stub.generate(
                context: AssembledContext(userPrompt: ""),
                generating: ConversationResponse.self
            )
            XCTFail("expected throw")
        } catch LanguageModelClientError.malformedGenerableOutput {
            // pass
        } catch {
            XCTFail("expected malformedGenerableOutput, got \(error)")
        }
    }

    func test_throwsConfiguredError() async {
        struct Boom: Error {}
        let stub = StubLanguageModelClient { _, _ in throw Boom() }
        do {
            let _: ConversationResponse = try await stub.generate(
                context: AssembledContext(userPrompt: ""),
                generating: ConversationResponse.self
            )
            XCTFail("expected throw")
        } catch is Boom {
            // pass — stub does not wrap; tests see the underlying error
        } catch {
            XCTFail("expected Boom, got \(error)")
        }
    }
}
```

- [ ] **Step 3.2 [VERIFY]: Run the test — it should fail to build**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter StubLanguageModelClientTests 2>&1 | tail -20
```

Expected: build error referencing `StubLanguageModelClient` (symbol not defined).

- [ ] **Step 3.3 [CC]: Implement the stub**

`b0tKit/Sources/b0tCore/Model/StubLanguageModelClient.swift`:

```swift
import Foundation
import FoundationModels

/// A test seam for `LanguageModelClient`. Constructed test-by-test with a
/// closure that maps `(AssembledContext, Output.Type)` to an `Any` result.
///
/// The stub does no orchestration — it doesn't honour `tools`, doesn't emit
/// streaming chunks, doesn't model rate-limiting. It exists so we can test
/// the *pipeline* (assembler → executor → journal) without involving the
/// real model. Tests that need to exercise model errors throw from the
/// closure. Tests that need to exercise specific outputs return them.
///
/// Typed-result mismatch (the closure returns a value of a different
/// `Generable` type from the one requested) is reported as
/// `LanguageModelClientError.malformedGenerableOutput` rather than a crash —
/// it would otherwise be a silent bug in the test, not an assertion failure.
public struct StubLanguageModelClient: LanguageModelClient {
    public typealias Handler = @Sendable (AssembledContext, any Generable.Type) throws -> Any

    private let handler: Handler

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    public func generate<Output: Generable>(
        context: AssembledContext,
        generating outputType: Output.Type
    ) async throws -> Output {
        let raw = try handler(context, outputType)
        guard let typed = raw as? Output else {
            throw LanguageModelClientError.malformedGenerableOutput(
                underlyingDescription: "stub returned \(type(of: raw)) for \(outputType)"
            )
        }
        return typed
    }
}
```

- [ ] **Step 3.4 [VERIFY]: Run the test — it should pass**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter StubLanguageModelClientTests 2>&1 | tail -20
```

Expected: 3 tests pass.

- [ ] **Step 3.5 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Model/StubLanguageModelClient.swift \
        b0tKit/Tests/b0tCoreTests/StubLanguageModelClientTests.swift
git commit -m "feat(b0tCore): StubLanguageModelClient — test seam for the model layer

A handler-driven stub that returns canned typed outputs to tests. Reports
typed-result mismatches as malformedGenerableOutput so the failure mode is
loud rather than silent. Tests cover canned-response, mismatch, and
error-propagation paths. See spec §5.3."
```

---

### Task 4: Skeleton `ConversationManager.respond(to:)`

**Files:**
- Create: `b0tKit/Sources/b0tCore/ConversationManager.swift`
- Create: `b0tKit/Sources/b0tCore/Support/Clock.swift`
- Create: `b0tKit/Tests/b0tCoreTests/ConversationManagerTests.swift`

**Why now:** With the stub in place we can write the orchestrator and test it end-to-end without any markdown, model, or journal involvement. Slice 2+ replaces the inline prompt-pass-through with a real `ContextAssembler` invocation.

- [ ] **Step 4.1 [CC]: Write the `Clock` protocol — needed by tests for deterministic time**

`b0tKit/Sources/b0tCore/Support/Clock.swift`:

```swift
import Foundation

/// A small abstraction over time for tests.
///
/// `SystemClock` reads the wall clock. `TestClock` (test-target only) returns
/// a fixed `Date` configured per test. Used by `ConversationManager`,
/// `HeartbeatManager`, `JournalWriter`, `MissedBeatDetector`, and
/// `TimeAwarenessTool` so deterministic timestamps are possible in tests.
public protocol Clock: Sendable {
    func now() -> Date
}

public struct SystemClock: Clock {
    public init() {}
    public func now() -> Date { Date() }
}
```

- [ ] **Step 4.2 [CC]: Write the failing test**

`b0tKit/Tests/b0tCoreTests/ConversationManagerTests.swift`:

```swift
import XCTest
import FoundationModels
@testable import b0tCore
@testable import b0tBrain

final class ConversationManagerTests: XCTestCase {
    func test_respond_passesPromptThroughToClient_returnsResponse() async throws {
        // Slice 1 behaviour: the manager is a thin wrapper that builds an
        // AssembledContext from the prompt alone (no markdown reads yet),
        // calls the client, and returns the response.
        let bot = try makeFixtureBot()
        let store = BotStore()
        let stub = StubLanguageModelClient { context, _ in
            XCTAssertEqual(context.userPrompt, "hello")
            return ConversationResponse(text: "echo: hello")
        }
        let manager = ConversationManager(bot: bot, store: store, client: stub)

        let response = try await manager.respond(to: "hello")

        XCTAssertEqual(response.text, "echo: hello")
    }

    private func makeFixtureBot() throws -> Bot {
        let fixturesURL = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/canonical-bot")
        let store = BotStore()
        return try awaitOnMain { try await store.load(at: fixturesURL) }
    }

    private func awaitOnMain<T>(_ work: @Sendable () async throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<T, Error>!
        Task {
            do { result = .success(try await work()) }
            catch { result = .failure(error) }
            semaphore.signal()
        }
        semaphore.wait()
        return try result.get()
    }
}
```

- [ ] **Step 4.3 [VERIFY]: Run the test — it should fail to build**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter ConversationManagerTests 2>&1 | tail -20
```

Expected: build error referencing `ConversationManager` (symbol not defined).

- [ ] **Step 4.4 [CC]: Implement `ConversationManager`**

`b0tKit/Sources/b0tCore/ConversationManager.swift`:

```swift
import Foundation
import FoundationModels
import b0tBrain

/// Orchestrates a single user-turn flow: prompt → context → model → response.
///
/// Slice 1 (this file): prompt is passed through as-is to the client.
/// Slice 2 (Task 9): wraps `ContextAssembler.assemble(.conversation(...))`.
/// Slice 3 (Task 14): applies `Executor` to memory observations.
/// Slice 4 (Task 17): appends a journal entry per turn.
///
/// The manager is an `actor` so concurrent UI inputs are serialised — the
/// caller doesn't have to coordinate. State that survives a single call
/// (turn-number counter for journaling) is held on the actor.
public actor ConversationManager {
    private let bot: Bot
    private let store: BotStore
    private let client: any LanguageModelClient
    private let clock: any Clock

    public init(
        bot: Bot,
        store: BotStore,
        client: any LanguageModelClient,
        clock: any Clock = SystemClock()
    ) {
        self.bot = bot
        self.store = store
        self.client = client
        self.clock = clock
    }

    public func respond(to userPrompt: String) async throws -> ConversationResponse {
        let context = AssembledContext(userPrompt: userPrompt)
        return try await client.generate(
            context: context,
            generating: ConversationResponse.self
        )
    }
}
```

- [ ] **Step 4.5 [VERIFY]: Run the test — it should pass**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter ConversationManagerTests 2>&1 | tail -20
```

Expected: 1 test passes.

- [ ] **Step 4.6 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/ConversationManager.swift \
        b0tKit/Sources/b0tCore/Support/Clock.swift \
        b0tKit/Tests/b0tCoreTests/ConversationManagerTests.swift
git commit -m "feat(b0tCore): ConversationManager skeleton + Clock protocol

Slice-1 ConversationManager — actor that wraps client.generate with a
single-field AssembledContext built from the user prompt. Later slices
replace the inline prompt with ContextAssembler output, run the response
through Executor, and append a journal entry. The Clock protocol exists
so later tests can pin timestamps; SystemClock is the production impl.
See spec §5.1."
```

---

### Task 5: `DebugBrainView` and wire into `b0tApp`

**Files:**
- Create: `b0tApp/Sources/Debug/DebugBrainView.swift`
- Modify: `b0tApp/Sources/App/ContentView.swift` (add DEBUG-only sheet entry point)

**Why now:** End of slice 1. After this task, the app launches in simulator, the user taps a debug button, sees a chat field, types a message, and gets a stub echo reply.

- [ ] **Step 5.1 [CC]: Write `DebugBrainView`**

`b0tApp/Sources/Debug/DebugBrainView.swift`:

```swift
#if DEBUG
import SwiftUI
import b0tCore
import b0tBrain

/// A throwaway debug surface for Phase 2 development.
///
/// Only compiled in DEBUG builds. Phase 4 replaces this with the real
/// anatomical GUI. Until then this view is the only surface that exercises
/// `ConversationManager` and (later) `HeartbeatManager` end-to-end on a
/// running app.
///
/// Slice 1 (this file): chat field + scrolling reply log, stub client only.
/// Slice 2 (Task 11): switch to `LiveLanguageModelClient` with stub fallback.
/// Slice 4 (Task 17): journal-tail pane.
/// Slice 5 (Task 22): "fire heartbeat now" button.
struct DebugBrainView: View {
    let bot: Bot
    let store: BotStore

    @State private var input: String = ""
    @State private var log: [LogEntry] = []
    @State private var isThinking: Bool = false

    private struct LogEntry: Identifiable {
        let id = UUID()
        let role: Role
        let text: String
        enum Role { case user, bot, status }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(log) { entry in
                        Text(entry.text)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(colour(for: entry.role))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            Divider()
            HStack {
                TextField("message", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isThinking)
                    .onSubmit { Task { await send() } }
                Button("send") { Task { await send() } }
                    .disabled(input.isEmpty || isThinking)
            }
            .padding()
        }
        .navigationTitle("debug brain")
    }

    private func colour(for role: LogEntry.Role) -> Color {
        switch role {
        case .user: return .primary
        case .bot: return .accentColor
        case .status: return .secondary
        }
    }

    private func send() async {
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        input = ""
        log.append(LogEntry(role: .user, text: "> \(prompt)"))
        isThinking = true
        defer { isThinking = false }

        let stub = StubLanguageModelClient { context, _ in
            ConversationResponse(text: "echo: \(context.userPrompt)")
        }
        let manager = ConversationManager(bot: bot, store: store, client: stub)

        do {
            let reply = try await manager.respond(to: prompt)
            log.append(LogEntry(role: .bot, text: reply.text))
        } catch {
            log.append(LogEntry(role: .status, text: "error: \(error)"))
        }
    }
}
#endif
```

- [ ] **Step 5.2 [CC]: Modify `ContentView.swift` to add a DEBUG-only entry point**

Replace the contents of `b0tApp/Sources/App/ContentView.swift` with:

```swift
import SwiftUI
import b0tBrain

struct ContentView: View {
    let bootstrap: Bootstrap

    #if DEBUG
    @State private var showDebugBrain = false
    #endif

    var body: some View {
        VStack(spacing: 8) {
            Text("b0t")
                .font(.system(.largeTitle, design: .monospaced))
            statusLine
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            #if DEBUG
            if case .ready = bootstrap {
                Button("debug brain") { showDebugBrain = true }
                    .font(.system(.caption, design: .monospaced))
                    .padding(.top, 16)
            }
            #endif
        }
        .padding()
        #if DEBUG
        .sheet(isPresented: $showDebugBrain) {
            if case .ready(let bot, let store) = bootstrap {
                NavigationStack {
                    DebugBrainView(bot: bot, store: store)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("close") { showDebugBrain = false }
                            }
                        }
                }
            }
        }
        #endif
    }

    @ViewBuilder
    private var statusLine: some View {
        switch bootstrap {
        case .pending:
            Text("provisioning...")
        case .ready(let bot, _):
            Text("active: \(bot.rootURL.lastPathComponent)")
        case .failed(let reason):
            Text("bootstrap failed: \(reason)")
        }
    }
}

#Preview {
    ContentView(bootstrap: .pending)
}
```

- [ ] **Step 5.3 [VERIFY]: Build the app for simulator**

```bash
cd /Users/haydentoppeross/development/b0t
xcrun xcodebuild build \
    -project b0t.xcodeproj \
    -scheme b0t \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug \
    2>&1 | tail -30
```

Expected: BUILD SUCCEEDED with zero warnings (warnings are errors per `project.yml`).

- [ ] **Step 5.4 [VERIFY]: Run all tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --no-parallel 2>&1 | tail -10
```

Expected: all tests pass — Phase 1 (78), Slice 1 stub + manager (4 tests so far), tombstone (1).

- [ ] **Step 5.5 [VERIFY]: Manual smoke (slice 1 acceptance)**

Document this in the PR description; the manual step is for the reviewer (or Jamee) to perform:

1. Open `b0t.xcodeproj` in Xcode.
2. Run on iPhone 16 simulator (DEBUG configuration).
3. App launches showing "active: b0t-01".
4. Tap "debug brain" — sheet opens with chat field.
5. Type "hello" and tap "send" — reply log shows `> hello` then `echo: hello`.

If this does not work, do not commit. Diagnose first.

- [ ] **Step 5.6 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tApp/Sources/Debug/DebugBrainView.swift \
        b0tApp/Sources/App/ContentView.swift
git commit -m "feat(b0tApp): DebugBrainView — slice 1 chat surface (stub client only)

DEBUG-only SwiftUI view presenting a chat field, scrolling reply log, and
echo-only stub client. ContentView gains a DEBUG-gated 'debug brain' button
that opens the view as a sheet. Slice 1 of Phase 2's walking-skeleton
plan: end-to-end loop runs without any markdown, model, or journal
involvement. Manual smoke: type a message, see canned echo reply. See
spec §9.4."
```

---

## Slice 2 — Real client + `ContextAssembler`

Goal of this slice: by end of Task 11, `DebugBrainView` calls `LiveLanguageModelClient` against real Apple Foundation Models on a real device (with stub fallback when FM is unavailable). `ContextAssembler` reads identity + memory files from the bot and produces a real prompt with token-budget logging.

This slice is the FM-API verification gate. If `FoundationModels` shapes differ from the spec's draft (e.g., `Generable` is named differently, `Tool` has a different protocol shape, `SystemLanguageModel` exposes availability differently), this is where we discover and adapt.

### Task 6: Real `AssembledContext`, `AssemblyMode`, `TokenBudget`

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Context/AssembledContext.swift` (replace Task 2's placeholder)
- Create: `b0tKit/Sources/b0tCore/Context/AssemblyMode.swift`
- Create: `b0tKit/Sources/b0tCore/Context/TokenBudget.swift`
- Create: `b0tKit/Tests/b0tCoreTests/AssembledContextTests.swift`

**Why now:** The assembler's outputs are the contract every Slice-2 component depends on. Define the value types first so Tasks 7-9 compile against a stable surface.

- [ ] **Step 6.1 [CC]: Write the failing test for `TokenBudget`**

`b0tKit/Tests/b0tCoreTests/AssembledContextTests.swift`:

```swift
import XCTest
import FoundationModels
@testable import b0tCore

final class AssembledContextTests: XCTestCase {
    func test_tokenBudget_summedBreakdownMatchesEstimated() {
        let budget = TokenBudget(
            estimated: 600,
            limit: 3500,
            breakdown: [
                "identity": 450,
                "memory": 100,
                "userPrompt": 50,
            ],
            didFallBackToDigest: false
        )
        XCTAssertEqual(budget.estimated, 600)
        XCTAssertEqual(budget.breakdown.values.reduce(0, +), 600)
        XCTAssertFalse(budget.didFallBackToDigest)
    }

    func test_assemblyMode_conversationCarriesPrompt() {
        let mode = AssemblyMode.conversation(userPrompt: "hello")
        if case .conversation(let prompt) = mode {
            XCTAssertEqual(prompt, "hello")
        } else {
            XCTFail("expected .conversation")
        }
    }

    func test_assemblyMode_heartbeatCarriesTriggerAndGap() {
        let mode = AssemblyMode.heartbeat(trigger: .scheduled, missedGap: .seconds(7200))
        if case .heartbeat(let trigger, let gap) = mode {
            XCTAssertEqual(trigger, .scheduled)
            XCTAssertEqual(gap, .seconds(7200))
        } else {
            XCTFail("expected .heartbeat")
        }
    }

    func test_assembledContext_carriesAllFields() {
        let budget = TokenBudget(
            estimated: 100, limit: 3500, breakdown: ["x": 100], didFallBackToDigest: false
        )
        let ctx = AssembledContext(
            systemInstructions: "you are b0t-01",
            userPrompt: "hi",
            tools: [],
            budget: budget,
            loadedFiles: ["identity/core.md"]
        )
        XCTAssertEqual(ctx.systemInstructions, "you are b0t-01")
        XCTAssertEqual(ctx.userPrompt, "hi")
        XCTAssertTrue(ctx.tools.isEmpty)
        XCTAssertEqual(ctx.budget.estimated, 100)
        XCTAssertEqual(ctx.loadedFiles, ["identity/core.md"])
    }
}
```

- [ ] **Step 6.2 [VERIFY]: Run the test — it should fail to build**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter AssembledContextTests 2>&1 | tail -20
```

Expected: build error referencing `TokenBudget`, `TickTrigger`, `AssemblyMode`, or the new `AssembledContext` shape.

- [ ] **Step 6.3 [CC]: Write the `TickTrigger` enum (lives in `Support/`)**

`b0tKit/Sources/b0tCore/Support/TickTrigger.swift`:

```swift
import Foundation

/// What woke the heartbeat.
///
/// Slice 5 wires `.scheduled` and `.manual`. The remaining cases are reserved
/// for Phase 4+ when real-device event triggers (significant location change,
/// calendar approaching, app foregrounded, notification received) are wired
/// through `BGTaskScheduler` event handlers.
public enum TickTrigger: String, Sendable, Equatable, CaseIterable {
    case scheduled
    case manual
    case locationChange
    case calendarApproaching
    case appForegrounded
    case notificationReceived
}
```

- [ ] **Step 6.4 [CC]: Write the `AssemblyMode` enum**

`b0tKit/Sources/b0tCore/Context/AssemblyMode.swift`:

```swift
import Foundation

/// What kind of assembled prompt the `ContextAssembler` should produce.
///
/// `.conversation` is a user-driven turn — the prompt body is the user's
/// message plus a snapshot of identity + memory + recent journal.
///
/// `.heartbeat` is a scheduled or event-triggered tick — the prompt body
/// includes the full text of `actions.md` (which drives per-beat behaviour)
/// plus the trigger context and any missed-beat gap.
///
/// `.fallback` is internal — used by `ContextAssembler`'s graduated overflow
/// recovery when the model returns `.exceededContextWindowSize`. Each level
/// drops more content (oldest journal entries → low-importance memory →
/// surface-the-overflow). See spec §7.4.
public enum AssemblyMode: Sendable {
    case conversation(userPrompt: String)
    case heartbeat(trigger: TickTrigger, missedGap: Duration?)
    case fallback(level: Int, base: BaseMode)

    public enum BaseMode: Sendable {
        case conversation(userPrompt: String)
        case heartbeat(trigger: TickTrigger, missedGap: Duration?)
    }
}
```

- [ ] **Step 6.5 [CC]: Write the `TokenBudget` value type**

`b0tKit/Sources/b0tCore/Context/TokenBudget.swift`:

```swift
import Foundation

/// A debug record of how the prompt's token budget was spent.
///
/// `estimated` is the assembler's pre-call estimate (Apple's tokenizer if
/// available, else 4-chars-per-token heuristic). `limit` is the configured
/// hard limit (typically 3500 — leaves ~500 tokens for the response, ~500
/// for the runtime's own overhead). `breakdown` is the per-section count so
/// DEBUG logs can identify which file pushed the prompt over.
///
/// `didFallBackToDigest` is set by `ContextAssembler` when the graduated
/// fallback (spec §7.4) had to drop content to fit. Writes to the journal
/// as part of the tick entry's `state_delta` for transparency.
public struct TokenBudget: Sendable, Equatable {
    public let estimated: Int
    public let limit: Int
    public let breakdown: [String: Int]
    public let didFallBackToDigest: Bool

    public init(
        estimated: Int,
        limit: Int,
        breakdown: [String: Int],
        didFallBackToDigest: Bool
    ) {
        self.estimated = estimated
        self.limit = limit
        self.breakdown = breakdown
        self.didFallBackToDigest = didFallBackToDigest
    }

    public var fitsWithinLimit: Bool { estimated <= limit }
}
```

- [ ] **Step 6.6 [CC]: Replace `AssembledContext.swift` with the full struct**

`b0tKit/Sources/b0tCore/Context/AssembledContext.swift`:

```swift
import Foundation
import FoundationModels

/// The output of `ContextAssembler.assemble(mode:)`.
///
/// Every model call goes through one of these. `LiveLanguageModelClient`
/// constructs a fresh `LanguageModelSession` from `tools` and `systemInstructions`
/// (sessions are short-lived per PRD §3.3) and calls `respond(to: userPrompt,
/// generating: Output.self)`.
///
/// `budget` and `loadedFiles` are diagnostics — never sent to the model. They
/// power DEBUG logging and (for `loadedFiles`) the `state_delta` field of
/// journal entries.
public struct AssembledContext: Sendable {
    public let systemInstructions: String
    public let userPrompt: String
    public let tools: [any Tool]
    public let budget: TokenBudget
    public let loadedFiles: [String]

    public init(
        systemInstructions: String,
        userPrompt: String,
        tools: [any Tool],
        budget: TokenBudget,
        loadedFiles: [String]
    ) {
        self.systemInstructions = systemInstructions
        self.userPrompt = userPrompt
        self.tools = tools
        self.budget = budget
        self.loadedFiles = loadedFiles
    }
}
```

- [ ] **Step 6.7 [CC]: Update `StubLanguageModelClient` callers and `ConversationManager` to construct full `AssembledContext`**

The Slice 1 stub-client tests and `ConversationManager.respond` build an `AssembledContext` with only `userPrompt`. Update them to use the new full constructor with placeholder budget/instructions.

Replace `ConversationManager.respond(to:)` body in `b0tKit/Sources/b0tCore/ConversationManager.swift`:

```swift
public func respond(to userPrompt: String) async throws -> ConversationResponse {
    let context = AssembledContext(
        systemInstructions: "",
        userPrompt: userPrompt,
        tools: [],
        budget: TokenBudget(
            estimated: 0, limit: 3500, breakdown: [:], didFallBackToDigest: false
        ),
        loadedFiles: []
    )
    return try await client.generate(
        context: context,
        generating: ConversationResponse.self
    )
}
```

Update `b0tKit/Tests/b0tCoreTests/StubLanguageModelClientTests.swift` to use the full constructor:

```swift
let context = AssembledContext(
    systemInstructions: "",
    userPrompt: "hi",
    tools: [],
    budget: TokenBudget(estimated: 0, limit: 3500, breakdown: [:], didFallBackToDigest: false),
    loadedFiles: []
)
```

(Apply the same change to the other two tests in that file — they construct contexts with empty prompts; just use the full constructor.)

Update `DebugBrainView.swift` similarly — `ConversationManager` builds the context internally now, so the view doesn't change. Verify by running the build.

- [ ] **Step 6.8 [VERIFY]: Run all tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --no-parallel 2>&1 | tail -15
```

Expected: all tests pass, including the new `AssembledContextTests` (4 tests), the updated `StubLanguageModelClientTests`, and `ConversationManagerTests`.

- [ ] **Step 6.9 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/ b0tKit/Tests/b0tCoreTests/
git commit -m "feat(b0tCore): real AssembledContext, AssemblyMode, TokenBudget, TickTrigger

Replaces the slice-1 placeholder AssembledContext with the full struct
(system instructions, user prompt, tools, budget breakdown, loaded files).
Introduces AssemblyMode (.conversation, .heartbeat, .fallback) and
TickTrigger (scheduled, manual, locationChange, ...). Updates Slice-1
callers to build the full context. See spec §5.4."
```

---

### Task 7: `ContextAssembler` — `.conversation` mode, identity + memory files

**Files:**
- Create: `b0tKit/Sources/b0tCore/Context/ContextAssembler.swift`
- Create: `b0tKit/Sources/b0tCore/Context/TokenEstimator.swift`
- Create: `b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift`

**Why now:** With value types in place, the assembler can be built and tested against the canonical-bot fixture without the model in the loop.

- [ ] **Step 7.1 [CC]: Write `TokenEstimator` first — separate file because it's standalone and reused**

`b0tKit/Sources/b0tCore/Context/TokenEstimator.swift`:

```swift
import Foundation

/// Estimates token count for a string.
///
/// Phase 2 ships a 4-chars-per-token heuristic — Apple's docs say "a single
/// token corresponds to approximately three to four characters in languages
/// like English, Spanish, or German" (see `LanguageModelSession.GenerationError.exceededContextWindowSize`).
/// 4 is the conservative upper bound for English, which biases the estimator
/// toward over-counting and triggering fallback earlier than strictly
/// necessary — better than under-counting.
///
/// If iOS exposes a public tokenizer in a future release, this estimator is
/// the single point to swap. The graduated overflow fallback in
/// `ContextAssembler` (spec §7.4) is the actual safety net — this is just
/// for budget logging and shaping.
public enum TokenEstimator {
    public static func estimate(_ text: String) -> Int {
        // Round up: a 5-character string is 2 tokens, not 1.
        let count = text.count
        return (count + 3) / 4
    }

    public static func estimate(_ texts: [String]) -> Int {
        texts.reduce(0) { $0 + estimate($1) }
    }
}
```

- [ ] **Step 7.2 [CC]: Write the failing test for `ContextAssembler` `.conversation` mode**

`b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift`:

```swift
import XCTest
import FoundationModels
@testable import b0tCore
@testable import b0tBrain

final class ContextAssemblerTests: XCTestCase {
    func test_conversation_includesIdentityCoreAndPrinciples() async throws {
        let bot = try await loadCanonicalBot()
        let assembler = ContextAssembler(bot: bot, store: BotStore())
        let context = try await assembler.assemble(mode: .conversation(userPrompt: "hi"))

        XCTAssertFalse(context.systemInstructions.isEmpty)
        XCTAssertTrue(context.systemInstructions.contains("b0t-01"),
                      "expected identity/core.md content in instructions")
        XCTAssertTrue(context.loadedFiles.contains("identity/core.md"))
        XCTAssertTrue(context.loadedFiles.contains("identity/principles.md"))
        XCTAssertTrue(context.loadedFiles.contains("memory/core.md"))
    }

    func test_conversation_userPromptCarriesUserMessage() async throws {
        let bot = try await loadCanonicalBot()
        let assembler = ContextAssembler(bot: bot, store: BotStore())
        let context = try await assembler.assemble(mode: .conversation(userPrompt: "remember the meeting"))

        XCTAssertTrue(context.userPrompt.contains("remember the meeting"))
    }

    func test_conversation_recordsBudgetBreakdown() async throws {
        let bot = try await loadCanonicalBot()
        let assembler = ContextAssembler(bot: bot, store: BotStore())
        let context = try await assembler.assemble(mode: .conversation(userPrompt: "hi"))

        XCTAssertGreaterThan(context.budget.estimated, 0)
        XCTAssertEqual(context.budget.limit, 3500)
        XCTAssertEqual(
            context.budget.breakdown.values.reduce(0, +),
            context.budget.estimated,
            "breakdown should sum to estimated"
        )
        XCTAssertNotNil(context.budget.breakdown["identity"])
        XCTAssertNotNil(context.budget.breakdown["memory"])
        XCTAssertNotNil(context.budget.breakdown["userPrompt"])
    }

    private func loadCanonicalBot() async throws -> Bot {
        let fixturesURL = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/canonical-bot")
        let store = BotStore()
        return try await store.load(at: fixturesURL)
    }
}
```

- [ ] **Step 7.3 [VERIFY]: Run the test — it should fail to build**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter ContextAssemblerTests 2>&1 | tail -20
```

Expected: build error referencing `ContextAssembler` (symbol not defined).

- [ ] **Step 7.4 [CC]: Implement `ContextAssembler`**

`b0tKit/Sources/b0tCore/Context/ContextAssembler.swift`:

```swift
import Foundation
import FoundationModels
import b0tBrain
import OSLog

/// Builds an `AssembledContext` for a given `AssemblyMode`.
///
/// Slice 2 (this file): handles `.conversation` mode by loading identity/core,
/// identity/principles, and memory/core from the bot. The user prompt is
/// rendered into `userPrompt` verbatim.
///
/// Slice 5 (Task 19) extends this to handle `.heartbeat` mode by additionally
/// including the full body of `actions.md` and any trigger/missed-gap context.
///
/// Slice 7 (Task 28) extends `.heartbeat` to prepend a missed-beat note when
/// `missedGap` exceeds `bpmInterval × 1.5`.
///
/// Slice 10 (Task 37) implements the graduated overflow fallback for
/// `.fallback(level:base:)` mode.
///
/// See spec §7.1, §7.2, §7.4.
public struct ContextAssembler: Sendable {
    private let bot: Bot
    private let store: BotStore

    private static let logger = Logger(subsystem: "com.toppeross.b0t.b0tCore", category: "ContextAssembler")
    private static let limit = 3500

    public init(bot: Bot, store: BotStore) {
        self.bot = bot
        self.store = store
    }

    public func assemble(mode: AssemblyMode) async throws -> AssembledContext {
        switch mode {
        case .conversation(let userPrompt):
            return try await assembleConversation(userPrompt: userPrompt)
        case .heartbeat:
            // Slice 5 implements this branch.
            fatalError("heartbeat mode not implemented until Slice 5")
        case .fallback:
            // Slice 10 implements this branch.
            fatalError("fallback mode not implemented until Slice 10")
        }
    }

    private func assembleConversation(userPrompt: String) async throws -> AssembledContext {
        let identityCore = try await bot.identity.core
        let identityPrinciples = try await bot.identity.principles
        let memoryCore = try await bot.memory.core

        let identityText = [identityCore.prose, identityPrinciples.prose].joined(separator: "\n\n")
        let memoryText = memoryCore.prose

        let systemInstructions = """
        you are the b0t named '\(bot.rootURL.lastPathComponent)'.

        identity:
        \(identityText)

        what you remember about the user:
        \(memoryText)
        """

        let identityTokens = TokenEstimator.estimate(identityText)
        let memoryTokens = TokenEstimator.estimate(memoryText)
        let promptTokens = TokenEstimator.estimate(userPrompt)
        let total = identityTokens + memoryTokens + promptTokens

        let breakdown = [
            "identity": identityTokens,
            "memory": memoryTokens,
            "userPrompt": promptTokens,
        ]

        let budget = TokenBudget(
            estimated: total,
            limit: Self.limit,
            breakdown: breakdown,
            didFallBackToDigest: false
        )

        Self.logger.debug("assembled conversation prompt — total: \(total), breakdown: \(breakdown)")

        return AssembledContext(
            systemInstructions: systemInstructions,
            userPrompt: userPrompt,
            tools: [],
            budget: budget,
            loadedFiles: [
                "identity/core.md",
                "identity/principles.md",
                "memory/core.md",
            ]
        )
    }
}
```

- [ ] **Step 7.5 [VERIFY]: Run the test — it should pass**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter ContextAssemblerTests 2>&1 | tail -20
```

Expected: 3 tests pass.

- [ ] **Step 7.6 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Context/ \
        b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift
git commit -m "feat(b0tCore): ContextAssembler — .conversation mode

Slice-2 ContextAssembler handles .conversation mode by loading identity/core,
identity/principles, and memory/core from the bot, building the system
instructions and user prompt envelope, and emitting a TokenBudget breakdown
for DEBUG logging. .heartbeat and .fallback modes fatalError until Slice 5
and Slice 10 respectively. TokenEstimator uses a 4-chars-per-token heuristic
with a one-line comment about the source (Apple's exceededContextWindowSize
docs). See spec §5.4, §7.1, §7.4."
```

---

### Task 8: Wire `ContextAssembler` into `ConversationManager`

**Files:**
- Modify: `b0tKit/Sources/b0tCore/ConversationManager.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/ConversationManagerTests.swift`

**Why now:** Slice 2's whole point is that real context flows through. After this task, when the stub's handler inspects `context.systemInstructions`, it sees real identity content.

- [ ] **Step 8.1 [CC]: Update the failing test in `ConversationManagerTests`**

Replace `test_respond_passesPromptThroughToClient_returnsResponse` with:

```swift
func test_respond_buildsAssembledContextFromBot_passesToClient() async throws {
    let bot = try await loadCanonicalBot()
    let store = BotStore()
    let stub = StubLanguageModelClient { context, _ in
        // Real context now: instructions reference the bot, prompt carries the user message.
        XCTAssertTrue(context.systemInstructions.contains("b0t-01"))
        XCTAssertTrue(context.userPrompt.contains("hello"))
        XCTAssertGreaterThan(context.budget.estimated, 0)
        return ConversationResponse(text: "echo: hello")
    }
    let manager = ConversationManager(bot: bot, store: store, client: stub)

    let response = try await manager.respond(to: "hello")

    XCTAssertEqual(response.text, "echo: hello")
}

private func loadCanonicalBot() async throws -> Bot {
    let fixturesURL = Bundle.module.resourceURL!
        .appendingPathComponent("Fixtures/canonical-bot")
    let store = BotStore()
    return try await store.load(at: fixturesURL)
}
```

Delete the old `makeFixtureBot` and `awaitOnMain` helpers — async tests can call `loadCanonicalBot` directly.

- [ ] **Step 8.2 [VERIFY]: Run the test — it should fail (the manager still uses the placeholder)**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter ConversationManagerTests 2>&1 | tail -20
```

Expected: failure with "expected 'b0t-01' in systemInstructions" or similar.

- [ ] **Step 8.3 [CC]: Update `ConversationManager.respond(to:)` to invoke the assembler**

`b0tKit/Sources/b0tCore/ConversationManager.swift`:

```swift
import Foundation
import FoundationModels
import b0tBrain

public actor ConversationManager {
    private let bot: Bot
    private let store: BotStore
    private let client: any LanguageModelClient
    private let clock: any Clock
    private let assembler: ContextAssembler

    public init(
        bot: Bot,
        store: BotStore,
        client: any LanguageModelClient,
        clock: any Clock = SystemClock()
    ) {
        self.bot = bot
        self.store = store
        self.client = client
        self.clock = clock
        self.assembler = ContextAssembler(bot: bot, store: store)
    }

    public func respond(to userPrompt: String) async throws -> ConversationResponse {
        let context = try await assembler.assemble(
            mode: .conversation(userPrompt: userPrompt)
        )
        return try await client.generate(
            context: context,
            generating: ConversationResponse.self
        )
    }
}
```

- [ ] **Step 8.4 [VERIFY]: Run all tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --no-parallel 2>&1 | tail -10
```

Expected: all tests pass.

- [ ] **Step 8.5 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/ConversationManager.swift \
        b0tKit/Tests/b0tCoreTests/ConversationManagerTests.swift
git commit -m "feat(b0tCore): wire ContextAssembler into ConversationManager

Replaces the slice-1 inline AssembledContext construction with a real
ContextAssembler invocation. The stub-driven test now asserts that
identity content is reachable from the assembled context. See spec §7.1."
```

---

### Task 9: `LiveLanguageModelClient` — wraps Apple `LanguageModelSession`

**Files:**
- Create: `b0tKit/Sources/b0tCore/Model/LiveLanguageModelClient.swift`

**Why now:** Tests against the live model are integration-only (gated, real-device required, in Slice 10). This task is about getting the wrapper compiled correctly against Apple's actual API. Verification is mostly via build success and a manual smoke on a device with FM available.

**API verification gate:** the spec calls this out — slice 2 is when the assumed FM API is reconciled with reality. If `Generable` is named differently, if `Tool` has a different shape, if `respond(to:generating:)` returns something other than `Response<T>`, fix it here and ripple changes through Tasks 2-8 as needed.

- [ ] **Step 9.1 [CC]: Implement `LiveLanguageModelClient`**

`b0tKit/Sources/b0tCore/Model/LiveLanguageModelClient.swift`:

```swift
import Foundation
import FoundationModels
import OSLog

/// Wraps Apple's `LanguageModelSession` for production use.
///
/// Per PRD §3.3, every model call is a fresh session — sessions are not
/// retained across user turns. The init checks `SystemLanguageModel.default`
/// availability and throws `.modelUnavailable` if Apple Intelligence is
/// disabled or the model isn't ready; callers (`DebugBrainView` in Phase 2,
/// `Home/` views in Phase 4) decide how to surface that.
///
/// Generation errors are mapped to `LanguageModelClientError`:
/// - `.exceededContextWindowSize` → `.exceededContextWindowSize`
/// - `.decodingFailure` → `.malformedGenerableOutput`
/// - all others → `.sessionFailed`
///
/// See spec §5.3.
public struct LiveLanguageModelClient: LanguageModelClient {
    private static let logger = Logger(subsystem: "com.toppeross.b0t.b0tCore", category: "LiveLanguageModelClient")

    public init() throws {
        guard SystemLanguageModel.default.isAvailable else {
            Self.logger.error("LiveLanguageModelClient init failed: SystemLanguageModel not available — \(String(describing: SystemLanguageModel.default.availability))")
            throw LanguageModelClientError.modelUnavailable
        }
    }

    public func generate<Output: Generable>(
        context: AssembledContext,
        generating outputType: Output.Type
    ) async throws -> Output {
        let session = LanguageModelSession(
            model: .default,
            tools: context.tools,
            instructions: {
                Instructions(context.systemInstructions)
            }
        )

        do {
            let response = try await session.respond(
                to: context.userPrompt,
                generating: outputType
            )
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                throw LanguageModelClientError.exceededContextWindowSize(
                    estimatedTokens: context.budget.estimated
                )
            case .decodingFailure:
                throw LanguageModelClientError.malformedGenerableOutput(
                    underlyingDescription: String(describing: error)
                )
            default:
                throw LanguageModelClientError.sessionFailed(
                    underlyingDescription: String(describing: error)
                )
            }
        } catch {
            throw LanguageModelClientError.sessionFailed(
                underlyingDescription: String(describing: error)
            )
        }
    }
}
```

- [ ] **Step 9.2 [VERIFY]: Build the package**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift build 2>&1 | tail -20
```

Expected: build succeeds. If any of the following fail, this is the verification gate firing — adapt the code rather than working around it:
- `Generable` not in scope → check for the actual protocol name (might be `Generable`-different in your iOS 26 SDK).
- `LanguageModelSession.init(model:tools:instructions:)` signature mismatch → use the real signature; closure may need to return `Instructions(...)` or a different builder shape.
- `Response.content` not present → the response type may have a different accessor.
- `LanguageModelSession.GenerationError` cases differ → update the switch.
- `SystemLanguageModel.default.isAvailable` not present → check `.availability` enum.

If you hit any of these, fix `LiveLanguageModelClient.swift` AND any of Tasks 2/3/6/7 that use the same names. Then re-run the build.

- [ ] **Step 9.3 [VERIFY]: Build the app for simulator**

```bash
cd /Users/haydentoppeross/development/b0t
xcrun xcodebuild build \
    -project b0t.xcodeproj \
    -scheme b0t \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug \
    2>&1 | tail -20
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 9.4 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Model/LiveLanguageModelClient.swift
git commit -m "feat(b0tCore): LiveLanguageModelClient — wraps Apple LanguageModelSession

Constructs a fresh LanguageModelSession per call (PRD §3.3 — sessions
short-lived). Maps GenerationError cases to LanguageModelClientError:
exceededContextWindowSize, decodingFailure → malformedGenerableOutput,
others → sessionFailed. Init checks SystemLanguageModel.default.isAvailable
and throws .modelUnavailable when Apple Intelligence is disabled / model
not ready. See spec §5.3."
```

---

### Task 10: Wire `LiveLanguageModelClient` into `DebugBrainView` with stub fallback

**Files:**
- Modify: `b0tApp/Sources/Debug/DebugBrainView.swift`

**Why now:** End of Slice 2. After this task, on a real device with Apple Intelligence enabled, the debug view talks to the real model. On simulator or device without FM, it falls back to the stub with a status line. `--use-stub-client` launch arg forces the stub.

- [ ] **Step 10.1 [CC]: Replace `DebugBrainView` with the slice-2 wiring**

`b0tApp/Sources/Debug/DebugBrainView.swift`:

```swift
#if DEBUG
import SwiftUI
import b0tCore
import b0tBrain

struct DebugBrainView: View {
    let bot: Bot
    let store: BotStore

    @State private var input: String = ""
    @State private var log: [LogEntry] = []
    @State private var isThinking: Bool = false
    @State private var manager: ConversationManager?
    @State private var modelStatus: ModelStatus = .uninitialized

    private struct LogEntry: Identifiable {
        let id = UUID()
        let role: Role
        let text: String
        enum Role { case user, bot, status }
    }

    private enum ModelStatus {
        case uninitialized
        case live
        case stub(reason: String)
    }

    var body: some View {
        VStack(spacing: 0) {
            modelStatusBanner
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(log) { entry in
                        Text(entry.text)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(colour(for: entry.role))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            Divider()
            HStack {
                TextField("message", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isThinking || manager == nil)
                    .onSubmit { Task { await send() } }
                Button("send") { Task { await send() } }
                    .disabled(input.isEmpty || isThinking || manager == nil)
            }
            .padding()
        }
        .navigationTitle("debug brain")
        .task { await initializeManager() }
    }

    @ViewBuilder
    private var modelStatusBanner: some View {
        switch modelStatus {
        case .uninitialized:
            Text("initializing model...")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        case .live:
            EmptyView()
        case .stub(let reason):
            Text("stub mode — \(reason)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }

    private func colour(for role: LogEntry.Role) -> Color {
        switch role {
        case .user: return .primary
        case .bot: return .accentColor
        case .status: return .secondary
        }
    }

    private func initializeManager() async {
        let forceStub = ProcessInfo.processInfo.arguments.contains("--use-stub-client")

        let client: any LanguageModelClient
        if forceStub {
            client = makeStub()
            modelStatus = .stub(reason: "--use-stub-client launch arg")
        } else {
            do {
                client = try LiveLanguageModelClient()
                modelStatus = .live
            } catch LanguageModelClientError.modelUnavailable {
                client = makeStub()
                modelStatus = .stub(reason: "model unavailable on this device")
            } catch {
                client = makeStub()
                modelStatus = .stub(reason: "init failed: \(error)")
            }
        }

        manager = ConversationManager(bot: bot, store: store, client: client)
    }

    private func makeStub() -> StubLanguageModelClient {
        StubLanguageModelClient { context, _ in
            ConversationResponse(text: "echo: \(context.userPrompt)")
        }
    }

    private func send() async {
        guard let manager else { return }
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        input = ""
        log.append(LogEntry(role: .user, text: "> \(prompt)"))
        isThinking = true
        defer { isThinking = false }

        do {
            let reply = try await manager.respond(to: prompt)
            log.append(LogEntry(role: .bot, text: reply.text))
        } catch {
            log.append(LogEntry(role: .status, text: "error: \(error)"))
        }
    }
}
#endif
```

- [ ] **Step 10.2 [VERIFY]: Build the app for simulator**

```bash
cd /Users/haydentoppeross/development/b0t
xcrun xcodebuild build \
    -project b0t.xcodeproj \
    -scheme b0t \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug \
    2>&1 | tail -20
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 10.3 [VERIFY]: Manual smoke on simulator**

1. Run the app on iPhone 16 simulator.
2. Tap "debug brain" → sheet opens.
3. Banner reads "stub mode — model unavailable on this device" (FM is generally unavailable on simulator).
4. Type "hello" → reply is `echo: hello` (stub).

- [ ] **Step 10.4 [VERIFY]: Manual smoke on real device (deferred to slice close)**

Document this for the reviewer; if a real device with Apple Intelligence enabled is available, run the app there and confirm:

1. Banner is empty (live mode).
2. Type "hello" → reply is something the model actually generated (not "echo:").
3. Type a long, off-topic message — the model's reply should be a coherent ConversationResponse.

If FM init throws an unexpected error (not `.modelUnavailable`), the stub falls back with a status banner showing the underlying error string — investigate before merging.

- [ ] **Step 10.5 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tApp/Sources/Debug/DebugBrainView.swift
git commit -m "feat(b0tApp): DebugBrainView wires LiveLanguageModelClient with stub fallback

The view now attempts LiveLanguageModelClient at .task time and falls back
to StubLanguageModelClient if FM is unavailable (with a banner showing
the reason). Launch arg --use-stub-client forces stub regardless. End of
Phase 2 Slice 2: real model in the loop on devices with Apple Intelligence;
stub keeps simulator and unsupported devices working. See spec §9.4."
```

---

## Slice 3 — Memory observations and `Executor`

Goal of this slice: by end of Task 13, the b0t can produce `MemoryObservation`s as part of a `ConversationResponse` and the `Executor` writes high/medium-importance ones to `memory/recent.md`. Cross-turn persistence works: turn 1 says "remember X", turn 2 sees X in the assembled context.

### Task 11: Full `ConversationResponse` fields + `MoodTag`, `Importance`, `MemoryObservation`

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Decisions/ConversationResponse.swift`
- Create: `b0tKit/Sources/b0tCore/Decisions/MoodTag.swift`
- Create: `b0tKit/Sources/b0tCore/Decisions/Importance.swift`
- Create: `b0tKit/Sources/b0tCore/Decisions/MemoryObservation.swift`
- Create: `b0tKit/Tests/b0tCoreTests/DecisionsTests.swift`

**Why now:** The Executor reads `MemoryObservation`s off the response. The full type shapes need to be locked in before Executor can be implemented.

- [ ] **Step 11.1 [CC]: Write `MoodTag`**

`b0tKit/Sources/b0tCore/Decisions/MoodTag.swift`:

```swift
import Foundation
import FoundationModels

/// The b0t's expressed mood. Each pixel-art face must support all 8 states
/// per PRD §5.4 (b0tFace, Phase 4). Listed in `MoodTag` so models and the
/// face rig share a vocabulary.
@Generable
public enum MoodTag: String, Sendable, Equatable, CaseIterable {
    case idle
    case speaking
    case thinking
    case surprised
    case sleepy
    case attentive
    case worried
    case delighted
}
```

- [ ] **Step 11.2 [CC]: Write `Importance`**

`b0tKit/Sources/b0tCore/Decisions/Importance.swift`:

```swift
import Foundation
import FoundationModels

/// How significant a memory observation is.
///
/// `.medium` and `.high` are persisted to `memory/recent.md` by the
/// Executor (Task 12). `.low` is logged in DEBUG only; it represents
/// transient noticing that doesn't warrant a memory write.
@Generable
public enum Importance: String, Sendable, Equatable, CaseIterable {
    case low
    case medium
    case high
}
```

- [ ] **Step 11.3 [CC]: Write `MemoryObservation`**

`b0tKit/Sources/b0tCore/Decisions/MemoryObservation.swift`:

```swift
import Foundation
import FoundationModels

/// A "remember this" payload the model can attach to any decision.
///
/// `about` is what the observation is about (a person, a project, a topic).
/// `what` is the observation itself. `importance` controls whether the
/// Executor persists it (medium/high → `memory/recent.md`) or just logs it.
@Generable
public struct MemoryObservation: Sendable, Equatable {
    @Guide(description: "Who or what the observation is about — a person's name, a project name, or a topic.")
    public let about: String

    @Guide(description: "The observation itself, as a single short sentence.")
    public let what: String

    @Guide(description: "How significant this observation is. low: transient, won't be persisted. medium: noteworthy. high: important — must be remembered.")
    public let importance: Importance

    public init(about: String, what: String, importance: Importance) {
        self.about = about
        self.what = what
        self.importance = importance
    }
}
```

- [ ] **Step 11.4 [CC]: Replace `ConversationResponse` with the full shape**

`b0tKit/Sources/b0tCore/Decisions/ConversationResponse.swift`:

```swift
import Foundation
import FoundationModels

/// The model's output for a user conversation turn.
///
/// `mood` is optional — the model only sets it when the mood meaningfully
/// changes. `memoryObservations` may be empty when the turn produces no
/// new things to remember.
///
/// Per spec §3 / §5.5, this type does NOT carry a `tool_calls` field —
/// Apple's `LanguageModelSession` orchestrates tool dispatch automatically
/// via the session's `tools:` parameter.
@Generable(representNilExplicitlyInGeneratedContent: true)
public struct ConversationResponse: Sendable, Equatable {
    @Guide(description: "The reply the b0t says to the user. Sentence case, warm, specific.")
    public let text: String

    @Guide(description: "The b0t's current mood, or nil if no meaningful change.")
    public let mood: MoodTag?

    @Guide(description: "Things to remember from this turn. Empty if nothing notable.")
    public let memoryObservations: [MemoryObservation]

    public init(text: String, mood: MoodTag? = nil, memoryObservations: [MemoryObservation] = []) {
        self.text = text
        self.mood = mood
        self.memoryObservations = memoryObservations
    }
}
```

- [ ] **Step 11.5 [CC]: Write equality / encoding sanity tests**

`b0tKit/Tests/b0tCoreTests/DecisionsTests.swift`:

```swift
import XCTest
import FoundationModels
@testable import b0tCore

final class DecisionsTests: XCTestCase {
    func test_conversationResponse_equality() {
        let a = ConversationResponse(
            text: "hello",
            mood: .delighted,
            memoryObservations: [
                MemoryObservation(about: "Jamee", what: "likes coffee", importance: .medium)
            ]
        )
        let b = ConversationResponse(
            text: "hello",
            mood: .delighted,
            memoryObservations: [
                MemoryObservation(about: "Jamee", what: "likes coffee", importance: .medium)
            ]
        )
        XCTAssertEqual(a, b)
    }

    func test_conversationResponse_defaultArguments() {
        let r = ConversationResponse(text: "hi")
        XCTAssertNil(r.mood)
        XCTAssertTrue(r.memoryObservations.isEmpty)
    }

    func test_memoryObservation_importanceCases() {
        XCTAssertEqual(Importance.allCases, [.low, .medium, .high])
    }

    func test_moodTag_hasEightCases() {
        XCTAssertEqual(MoodTag.allCases.count, 8)
    }
}
```

- [ ] **Step 11.6 [VERIFY]: Run the tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter DecisionsTests 2>&1 | tail -10
swift test --no-parallel 2>&1 | tail -10
```

Expected: 4 new tests pass; existing tests (including `StubLanguageModelClientTests` which constructs `ConversationResponse` with the slice-1 single-arg init via the new default arguments) all still pass.

- [ ] **Step 11.7 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Decisions/ \
        b0tKit/Tests/b0tCoreTests/DecisionsTests.swift
git commit -m "feat(b0tCore): full ConversationResponse + MoodTag + Importance + MemoryObservation

Promotes ConversationResponse from one field to three (text, mood,
memoryObservations) with @Guide-annotated fields and
representNilExplicitlyInGeneratedContent for the optional mood. Adds
MoodTag (8 cases per PRD §5.4) and Importance (low/medium/high). The
default-arg init keeps Slice-1 callers source-compatible. See spec §6."
```

---

### Task 12: `Executor` + `StateDelta` — write memory observations to `memory/recent.md`

**Files:**
- Create: `b0tKit/Sources/b0tCore/Apply/StateDelta.swift`
- Create: `b0tKit/Sources/b0tCore/Apply/Executor.swift`
- Create: `b0tKit/Tests/b0tCoreTests/ExecutorTests.swift`

**Why now:** The Executor's job is small but its boundary matters: it's the only thing that writes to disk on the model's behalf. Defining it cleanly here means the heartbeat path (Slice 5+) reuses the same code with no surprises.

- [ ] **Step 12.1 [CC]: Write `StateDelta`**

`b0tKit/Sources/b0tCore/Apply/StateDelta.swift`:

```swift
import Foundation

/// A record of what changed on disk during one Executor run.
///
/// `writtenFiles` is the set of file URLs the Executor mutated — used by
/// JournalWriter to populate the `state_delta` field of OpenClaw entries.
///
/// `wouldNotifyText` is set when the model's decision is interpreted as
/// user-facing intent (e.g., a heartbeat tick that "decided: notify_user").
/// Phase 2 does NOT post real notifications via UNUserNotificationCenter —
/// Phase 4+ wires that. Until then, `wouldNotifyText` is captured and
/// journaled for inspection.
public struct StateDelta: Sendable, Equatable {
    public let writtenFiles: Set<URL>
    public let wouldNotifyText: String?

    public init(writtenFiles: Set<URL> = [], wouldNotifyText: String? = nil) {
        self.writtenFiles = writtenFiles
        self.wouldNotifyText = wouldNotifyText
    }

    public static let empty = StateDelta()
}
```

- [ ] **Step 12.2 [CC]: Write the failing test**

`b0tKit/Tests/b0tCoreTests/ExecutorTests.swift`:

```swift
import XCTest
import FoundationModels
@testable import b0tCore
@testable import b0tBrain

final class ExecutorTests: XCTestCase {
    func test_apply_writesMediumAndHighImportanceObservationsToMemoryRecent() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()
        let executor = Executor(bot: bot, store: store)

        let response = ConversationResponse(
            text: "noted",
            memoryObservations: [
                MemoryObservation(about: "Jamee", what: "vendor call at 4pm", importance: .high),
                MemoryObservation(about: "weather", what: "looks like rain", importance: .low),
                MemoryObservation(about: "work_tracker", what: "deadline tomorrow", importance: .medium),
            ]
        )

        let delta = try await executor.apply(response)

        XCTAssertEqual(delta.writtenFiles.count, 1, "exactly one file should be written: memory/recent.md")
        XCTAssertNil(delta.wouldNotifyText)

        // Re-read memory/recent.md and confirm the medium and high observations are present.
        let recent = try await bot.memory.recent
        XCTAssertTrue(recent.prose.contains("Jamee"))
        XCTAssertTrue(recent.prose.contains("vendor call at 4pm"))
        XCTAssertTrue(recent.prose.contains("work_tracker"))
        XCTAssertTrue(recent.prose.contains("deadline tomorrow"))
        XCTAssertFalse(recent.prose.contains("looks like rain"),
                       ".low importance must not be persisted")
    }

    func test_apply_emptyObservations_writesNothing() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()
        let executor = Executor(bot: bot, store: store)

        let response = ConversationResponse(text: "noted", memoryObservations: [])
        let delta = try await executor.apply(response)

        XCTAssertTrue(delta.writtenFiles.isEmpty)
        XCTAssertNil(delta.wouldNotifyText)
    }

    func test_apply_observationsAreNewestFirst() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()
        let executor = Executor(bot: bot, store: store)

        // Apply two responses; the second's observation should appear before the first's
        // in memory/recent.md.
        _ = try await executor.apply(ConversationResponse(
            text: "first",
            memoryObservations: [
                MemoryObservation(about: "topic", what: "first observation", importance: .high)
            ]
        ))
        _ = try await executor.apply(ConversationResponse(
            text: "second",
            memoryObservations: [
                MemoryObservation(about: "topic", what: "second observation", importance: .high)
            ]
        ))

        let recent = try await bot.memory.recent
        let firstIndex = recent.prose.range(of: "first observation")!.lowerBound
        let secondIndex = recent.prose.range(of: "second observation")!.lowerBound
        XCTAssertLessThan(secondIndex, firstIndex,
                          "newest observation should appear first")
    }

    private func loadCanonicalBotInTempCopy() async throws -> Bot {
        let fixture = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/canonical-bot")
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: fixture, to: temp)
        addTeardownBlock { try? FileManager.default.removeItem(at: temp) }
        let store = BotStore()
        return try await store.load(at: temp)
    }
}
```

- [ ] **Step 12.3 [VERIFY]: Run the test — it should fail to build**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter ExecutorTests 2>&1 | tail -20
```

Expected: build error referencing `Executor` (symbol not defined).

- [ ] **Step 12.4 [CC]: Implement `Executor`**

`b0tKit/Sources/b0tCore/Apply/Executor.swift`:

```swift
import Foundation
import FoundationModels
import b0tBrain
import OSLog

/// Applies a model decision to the bot's on-disk state.
///
/// Slice 3 (this file): writes high/medium-importance memory observations
/// to `memory/recent.md` (newest-first) and returns a StateDelta listing
/// the files written.
///
/// Slice 5 (Task 21) adds `apply(_ decision: TickDecision)` for heartbeat
/// ticks — same observation logic, plus optional `wouldNotifyText` capture.
///
/// Slice 6 (Task 26) adds notification budget enforcement.
///
/// Per spec §5.6, the Executor never posts real notifications in Phase 2.
public struct Executor: Sendable {
    private let bot: Bot
    private let store: BotStore

    private static let logger = Logger(subsystem: "com.toppeross.b0t.b0tCore", category: "Executor")
    private static let recentEntryHeading = "## "

    public init(bot: Bot, store: BotStore) {
        self.bot = bot
        self.store = store
    }

    public func apply(_ response: ConversationResponse) async throws -> StateDelta {
        let persistable = response.memoryObservations.filter { $0.importance != .low }

        // Log .low observations in DEBUG without persisting.
        for observation in response.memoryObservations where observation.importance == .low {
            Self.logger.debug("memory observation (low, not persisted): \(observation.about) — \(observation.what)")
        }

        guard !persistable.isEmpty else {
            return .empty
        }

        let recentURL = bot.memory.recentURL
        let existing = try await bot.memory.recent
        let newProse = prependObservations(persistable, to: existing.prose)
        let updated = existing.replacingProse(with: newProse)
        try await store.write(updated)

        return StateDelta(writtenFiles: [recentURL])
    }

    private func prependObservations(_ observations: [MemoryObservation], to existing: String) -> String {
        // Each observation becomes a markdown bullet stamped with its importance.
        // Newest-first: prepend the new lines above any existing content, separated by a blank line.
        let block = observations.map { obs in
            "- (\(obs.importance.rawValue)) \(obs.about): \(obs.what)"
        }.joined(separator: "\n")

        if existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return block + "\n"
        }
        return block + "\n\n" + existing
    }
}
```

- [ ] **Step 12.5 [VERIFY]: Run the tests — they should pass**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter ExecutorTests 2>&1 | tail -15
```

Expected: 3 tests pass.

- [ ] **Step 12.6 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Apply/ \
        b0tKit/Tests/b0tCoreTests/ExecutorTests.swift
git commit -m "feat(b0tCore): Executor.apply(ConversationResponse) — memory observation writes

Slice-3 Executor writes medium/high-importance MemoryObservations to
memory/recent.md (newest-first, markdown bullet format). Low-importance
observations are logged in DEBUG but not persisted. Returns a StateDelta
listing the written file URLs for the JournalWriter to record. See
spec §5.5, §7.1."
```

---

### Task 13: Wire `Executor` into `ConversationManager`

**Files:**
- Modify: `b0tKit/Sources/b0tCore/ConversationManager.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/ConversationManagerTests.swift`

**Why now:** End of Slice 3. After this task, a stub-driven test can prove that turn 1's observations land in `memory/recent.md` and turn 2's `ContextAssembler` reads them back into the next prompt.

- [ ] **Step 13.1 [CC]: Add the cross-turn persistence test**

Append to `b0tKit/Tests/b0tCoreTests/ConversationManagerTests.swift`:

```swift
func test_respond_appliesMemoryObservations_persistsAcrossTurns() async throws {
    let bot = try await loadCanonicalBotInTempCopy()
    let store = BotStore()

    var turn = 0
    let stub = StubLanguageModelClient { context, _ in
        turn += 1
        if turn == 1 {
            return ConversationResponse(
                text: "noted",
                memoryObservations: [
                    MemoryObservation(
                        about: "Jamee",
                        what: "has a vendor call at 4pm",
                        importance: .high
                    )
                ]
            )
        } else {
            // Second turn: assert the assembler picked up the observation
            // from memory/recent.md (which was written by the first turn).
            XCTAssertTrue(
                context.systemInstructions.contains("vendor call at 4pm"),
                "second turn's instructions should include the first turn's observation"
            )
            return ConversationResponse(text: "remembered")
        }
    }
    let manager = ConversationManager(bot: bot, store: store, client: stub)

    _ = try await manager.respond(to: "I have a vendor call at 4 today")
    let second = try await manager.respond(to: "what's on my calendar?")
    XCTAssertEqual(second.text, "remembered")
}

private func loadCanonicalBotInTempCopy() async throws -> Bot {
    let fixture = Bundle.module.resourceURL!
        .appendingPathComponent("Fixtures/canonical-bot")
    let temp = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.copyItem(at: fixture, to: temp)
    addTeardownBlock { try? FileManager.default.removeItem(at: temp) }
    let store = BotStore()
    return try await store.load(at: temp)
}
```

(Update `loadCanonicalBot` from Task 8 to be a temp-copy helper too, or keep the existing read-only one and add this temp-copy variant. Since this test mutates files, it MUST use a temp copy.)

- [ ] **Step 13.2 [VERIFY]: Run the test — it should fail (the manager doesn't apply Executor yet)**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter ConversationManagerTests/test_respond_appliesMemoryObservations 2>&1 | tail -15
```

Expected: failure with "second turn's instructions should include the first turn's observation".

- [ ] **Step 13.3 [CC]: Update `ConversationManager.respond` to invoke the Executor**

`b0tKit/Sources/b0tCore/ConversationManager.swift`:

```swift
import Foundation
import FoundationModels
import b0tBrain

public actor ConversationManager {
    private let bot: Bot
    private let store: BotStore
    private let client: any LanguageModelClient
    private let clock: any Clock
    private let assembler: ContextAssembler
    private let executor: Executor

    public init(
        bot: Bot,
        store: BotStore,
        client: any LanguageModelClient,
        clock: any Clock = SystemClock()
    ) {
        self.bot = bot
        self.store = store
        self.client = client
        self.clock = clock
        self.assembler = ContextAssembler(bot: bot, store: store)
        self.executor = Executor(bot: bot, store: store)
    }

    public func respond(to userPrompt: String) async throws -> ConversationResponse {
        let context = try await assembler.assemble(
            mode: .conversation(userPrompt: userPrompt)
        )
        let response = try await client.generate(
            context: context,
            generating: ConversationResponse.self
        )
        _ = try await executor.apply(response)
        return response
    }
}
```

- [ ] **Step 13.4 [VERIFY]: Run all tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --no-parallel 2>&1 | tail -10
```

Expected: all tests pass — including the cross-turn persistence test.

- [ ] **Step 13.5 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/ConversationManager.swift \
        b0tKit/Tests/b0tCoreTests/ConversationManagerTests.swift
git commit -m "feat(b0tCore): ConversationManager applies Executor after every turn

Threading the Executor through the conversation flow: prompt → context →
client → executor → response. The cross-turn persistence test proves
turn-1 observations land in memory/recent.md and turn-2's assembler
picks them up. End of Phase 2 Slice 3. See spec §7.1."
```

---

## Slice 4 — `JournalWriter` and conversation journaling

Goal of this slice: by end of Task 16, every conversation turn appends a `## HH:MM — turn N` OpenClaw-format entry to `journal/YYYY-MM-DD.md`. `DebugBrainView` shows a live tail of the journal.

### Task 14: `EntryKind` + `JournalWriter` scaffolding (file resolution, date frontmatter on first append)

**Files:**
- Create: `b0tKit/Sources/b0tCore/Apply/EntryKind.swift`
- Create: `b0tKit/Sources/b0tCore/Apply/JournalWriter.swift` (scaffolding only — `appendConversationTurn` lands in Task 15)
- Create: `b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift`

**Why now:** The file-resolution and first-append-creates-frontmatter logic is shared across all four entry variants. Getting it right here makes Tasks 15, 17, 21, 23, 38 each be a single focused diff.

- [ ] **Step 14.1 [CC]: Write `EntryKind`**

`b0tKit/Sources/b0tCore/Apply/EntryKind.swift`:

```swift
import Foundation

/// Discriminator for which kind of journal entry a write is producing.
///
/// Used by `JournalWriter.appendError(error:kind:)` (Slice 10) so a single
/// error path serves both conversation turns and heartbeat ticks. The
/// `appendConversationTurn` and `appendTick` methods don't take this enum
/// because they're already kind-specific.
public enum EntryKind: Sendable, Equatable {
    case turn(number: Int)
    case heartbeat(number: Int)
}
```

- [ ] **Step 14.2 [CC]: Write the failing test for journal-file resolution and first-append frontmatter**

`b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift`:

```swift
import XCTest
import FoundationModels
@testable import b0tCore
@testable import b0tBrain

final class JournalWriterTests: XCTestCase {
    final class FixedClock: Clock, @unchecked Sendable {
        var date: Date
        init(_ date: Date) { self.date = date }
        func now() -> Date { date }
    }

    func test_journalFileURL_isDayKeyed() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()

        // 2026-05-01 14:32:00 UTC — round-tripped through the writer's date format.
        let date = ISO8601DateFormatter().date(from: "2026-05-01T14:32:00Z")!
        let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

        let url = writer.journalURL(for: date)
        XCTAssertTrue(url.lastPathComponent == "2026-05-01.md", "got: \(url.lastPathComponent)")
        XCTAssertTrue(url.path.contains("/journal/"))
    }

    func test_firstAppend_createsFileWithDateFrontmatter() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()

        let date = ISO8601DateFormatter().date(from: "2026-05-01T14:32:00Z")!
        let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

        // The bare scaffolding can be exercised by writing a single error entry
        // (which lands the date frontmatter), then re-reading the file directly.
        // Real entry-shape tests live in Task 15.
        try await writer.ensureJournalExists(for: date)

        let url = writer.journalURL(for: date)
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.hasPrefix("---\n"))
        XCTAssertTrue(content.contains("date: 2026-05-01\n"))
        XCTAssertTrue(content.contains("---\n"))
    }

    func test_secondAppend_doesNotReWriteFrontmatter() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()

        let date = ISO8601DateFormatter().date(from: "2026-05-01T14:32:00Z")!
        let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

        try await writer.ensureJournalExists(for: date)
        let firstContent = try String(
            contentsOf: writer.journalURL(for: date),
            encoding: .utf8
        )
        try await writer.ensureJournalExists(for: date)
        let secondContent = try String(
            contentsOf: writer.journalURL(for: date),
            encoding: .utf8
        )
        XCTAssertEqual(firstContent, secondContent,
                       "second ensure must be a no-op when file exists")
    }

    private func loadCanonicalBotInTempCopy() async throws -> Bot {
        let fixture = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/canonical-bot")
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: fixture, to: temp)
        addTeardownBlock { try? FileManager.default.removeItem(at: temp) }
        let store = BotStore()
        return try await store.load(at: temp)
    }
}
```

- [ ] **Step 14.3 [VERIFY]: Run the test — it should fail to build**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter JournalWriterTests 2>&1 | tail -20
```

Expected: build error referencing `JournalWriter`.

- [ ] **Step 14.4 [CC]: Implement `JournalWriter` scaffolding**

`b0tKit/Sources/b0tCore/Apply/JournalWriter.swift`:

```swift
import Foundation
import FoundationModels
import b0tBrain
import OSLog

/// Appends OpenClaw-format entries to `journal/YYYY-MM-DD.md`.
///
/// Slice 4 (this file): scaffolding + appendConversationTurn (Task 15).
/// Slice 5 (Task 21): appendTick.
/// Slice 6 (Task 23): appendSuppressed.
/// Slice 10 (Task 38): appendError.
///
/// Per spec §7.3, the journal file's day-keyed name comes from the writer's
/// clock (in the bot's time zone — UTC for now; Phase 4 may revisit). The
/// first append of a day creates the file with `---\ndate: YYYY-MM-DD\n---\n`
/// frontmatter. Subsequent appends to the same day's file just add an entry
/// after the existing content, separated by a blank line.
public struct JournalWriter: Sendable {
    private let bot: Bot
    private let store: BotStore
    private let clock: any Clock

    private static let logger = Logger(subsystem: "com.toppeross.b0t.b0tCore", category: "JournalWriter")

    public init(bot: Bot, store: BotStore, clock: any Clock) {
        self.bot = bot
        self.store = store
        self.clock = clock
    }

    /// The on-disk URL for the journal file representing `date`'s day.
    public func journalURL(for date: Date) -> URL {
        let dayString = Self.dayString(for: date)
        return bot.journal.directoryURL
            .appendingPathComponent("\(dayString).md")
    }

    /// Idempotent: creates `journal/YYYY-MM-DD.md` with date frontmatter if it
    /// does not yet exist. No-op otherwise.
    public func ensureJournalExists(for date: Date) async throws {
        let url = journalURL(for: date)
        if FileManager.default.fileExists(atPath: url.path) { return }

        try FileManager.default.createDirectory(
            at: bot.journal.directoryURL,
            withIntermediateDirectories: true
        )

        let dayString = Self.dayString(for: date)
        let initial = """
        ---
        date: \(dayString)
        ---


        """
        try initial.data(using: .utf8)!.write(to: url, options: .atomic)
    }

    /// The "YYYY-MM-DD" string for `date` in UTC. Phase 4 may switch to the
    /// user's local time zone — the spec leaves this open.
    static func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    /// The "HH:MM" string for `date` in UTC.
    static func timeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    /// Append `entry` to the journal file for `date`'s day, creating the file
    /// if it does not exist. Internal helper used by all four append methods.
    func appendRaw(_ entry: String, for date: Date) async throws {
        try await ensureJournalExists(for: date)
        let url = journalURL(for: date)
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let separator = existing.hasSuffix("\n\n") ? "" : (existing.hasSuffix("\n") ? "\n" : "\n\n")
        let combined = existing + separator + entry + "\n"
        try combined.data(using: .utf8)!.write(to: url, options: .atomic)
    }
}
```

- [ ] **Step 14.5 [VERIFY]: Run the tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter JournalWriterTests 2>&1 | tail -15
```

Expected: 3 tests pass.

- [ ] **Step 14.6 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Apply/EntryKind.swift \
        b0tKit/Sources/b0tCore/Apply/JournalWriter.swift \
        b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift
git commit -m "feat(b0tCore): JournalWriter scaffolding + EntryKind enum

File-resolution and first-append-creates-frontmatter logic shared by all
four append variants (appendConversationTurn lands in Task 15, then tick,
suppressed, error follow). Day-keyed naming via UTC dayString; subsequent
appends are blank-line separated. See spec §7.3."
```

---

### Task 15: `appendConversationTurn` — byte-exact OpenClaw output

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Apply/JournalWriter.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift`

**Why now:** Locking the OpenClaw text format with byte-exact tests means later append variants (tick, suppressed, error) are diff-only changes against this template.

- [ ] **Step 15.1 [CC]: Add the byte-exact test**

Append to `b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift`:

```swift
func test_appendConversationTurn_writesByteExactOpenClawEntry() async throws {
    let bot = try await loadCanonicalBotInTempCopy()
    let store = BotStore()

    let date = ISO8601DateFormatter().date(from: "2026-05-01T14:32:00Z")!
    let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

    let response = ConversationResponse(
        text: "noted — added to your memory",
        mood: .attentive,
        memoryObservations: [
            MemoryObservation(
                about: "Jamee",
                what: "vendor call at 4pm",
                importance: .high
            )
        ]
    )
    let stateDelta = StateDelta(
        writtenFiles: [bot.memory.recentURL]
    )

    try await writer.appendConversationTurn(
        prompt: "remember I have a vendor call at 4",
        response: response,
        stateDelta: stateDelta,
        turnNumber: 7
    )

    let url = writer.journalURL(for: date)
    let content = try String(contentsOf: url, encoding: .utf8)

    let expected = """
    ---
    date: 2026-05-01
    ---

    ## 14:32 — turn 7

    **observed:** user said: remember I have a vendor call at 4
    **decided:** noted — added to your memory
    **mood:** attentive
    **memory_observations:**
    - (high) Jamee: vendor call at 4pm
    **state_delta:** memory/recent.md

    """
    XCTAssertEqual(content, expected)
}

func test_appendConversationTurn_omitsOptionalSectionsWhenEmpty() async throws {
    let bot = try await loadCanonicalBotInTempCopy()
    let store = BotStore()

    let date = ISO8601DateFormatter().date(from: "2026-05-01T09:15:00Z")!
    let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

    try await writer.appendConversationTurn(
        prompt: "hi",
        response: ConversationResponse(text: "hello"),
        stateDelta: .empty,
        turnNumber: 1
    )

    let content = try String(contentsOf: writer.journalURL(for: date), encoding: .utf8)
    XCTAssertTrue(content.contains("## 09:15 — turn 1"))
    XCTAssertTrue(content.contains("**observed:** user said: hi"))
    XCTAssertTrue(content.contains("**decided:** hello"))
    XCTAssertTrue(content.contains("**state_delta:** none"))
    XCTAssertFalse(content.contains("**mood:**"), "mood section omitted when nil")
    XCTAssertFalse(content.contains("**memory_observations:**"), "observations section omitted when empty")
}
```

- [ ] **Step 15.2 [VERIFY]: Run the tests — they should fail to build**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter JournalWriterTests/test_appendConversationTurn 2>&1 | tail -15
```

Expected: build error — `appendConversationTurn` not defined.

- [ ] **Step 15.3 [CC]: Implement `appendConversationTurn`**

Append to `b0tKit/Sources/b0tCore/Apply/JournalWriter.swift` (inside the struct):

```swift
public func appendConversationTurn(
    prompt: String,
    response: ConversationResponse,
    stateDelta: StateDelta,
    turnNumber: Int
) async throws {
    let date = clock.now()
    let timeString = Self.timeString(for: date)
    let stateDeltaText = Self.formatStateDelta(stateDelta, bot: bot)

    var lines: [String] = [
        "## \(timeString) — turn \(turnNumber)",
        "",
        "**observed:** user said: \(prompt)",
        "**decided:** \(response.text)",
    ]

    if let mood = response.mood {
        lines.append("**mood:** \(mood.rawValue)")
    }

    if !response.memoryObservations.isEmpty {
        lines.append("**memory_observations:**")
        for obs in response.memoryObservations {
            lines.append("- (\(obs.importance.rawValue)) \(obs.about): \(obs.what)")
        }
    }

    lines.append("**state_delta:** \(stateDeltaText)")

    let entry = lines.joined(separator: "\n")
    try await appendRaw(entry, for: date)
}

static func formatStateDelta(_ delta: StateDelta, bot: Bot) -> String {
    if delta.writtenFiles.isEmpty && delta.wouldNotifyText == nil {
        return "none"
    }
    let pathPrefix = bot.rootURL.path
    let relative = delta.writtenFiles.map { url -> String in
        let path = url.path
        if path.hasPrefix(pathPrefix) {
            // Strip "<bot-root>/" prefix → e.g., "memory/recent.md"
            return String(path.dropFirst(pathPrefix.count + 1))
        }
        return url.lastPathComponent
    }.sorted()
    var parts = relative
    if let notify = delta.wouldNotifyText {
        parts.append("would_notify: \(notify)")
    }
    return parts.joined(separator: ", ")
}
```

- [ ] **Step 15.4 [VERIFY]: Run the tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter JournalWriterTests 2>&1 | tail -15
```

Expected: all 5 `JournalWriterTests` pass.

- [ ] **Step 15.5 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Apply/JournalWriter.swift \
        b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift
git commit -m "feat(b0tCore): JournalWriter.appendConversationTurn — byte-exact OpenClaw

Adds appendConversationTurn producing entries shaped per spec §7.3:
'## HH:MM — turn N' header, observed/decided/mood/memory_observations/state_delta
fields. Mood and observations sections are omitted when empty.
state_delta uses paths relative to the bot root, sorted lexically. Two
byte-exact tests pin the format. See spec §7.3."
```

---

### Task 16: Wire `JournalWriter` into `ConversationManager` + journal-tail pane in `DebugBrainView`

**Files:**
- Modify: `b0tKit/Sources/b0tCore/ConversationManager.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/ConversationManagerTests.swift`
- Modify: `b0tApp/Sources/Debug/DebugBrainView.swift`

**Why now:** End of Slice 4. After this task, every conversation turn appends a journal entry, and `DebugBrainView` shows the live tail.

- [ ] **Step 16.1 [CC]: Add the failing test**

Append to `b0tKit/Tests/b0tCoreTests/ConversationManagerTests.swift`:

```swift
func test_respond_appendsJournalEntryPerTurn() async throws {
    let bot = try await loadCanonicalBotInTempCopy()
    let store = BotStore()

    let stub = StubLanguageModelClient { _, _ in
        ConversationResponse(text: "hello back")
    }
    let manager = ConversationManager(bot: bot, store: store, client: stub)

    _ = try await manager.respond(to: "hi")
    _ = try await manager.respond(to: "anything new?")

    // Find today's journal file.
    let journalDir = bot.journal.directoryURL
    let entries = try FileManager.default.contentsOfDirectory(
        at: journalDir,
        includingPropertiesForKeys: nil
    )
    let mdFiles = entries.filter { $0.pathExtension == "md" }
    XCTAssertEqual(mdFiles.count, 1, "exactly one journal file should exist for today")

    let content = try String(contentsOf: mdFiles[0], encoding: .utf8)
    XCTAssertTrue(content.contains("turn 1"), "first turn should be numbered 1")
    XCTAssertTrue(content.contains("turn 2"), "second turn should be numbered 2")
    XCTAssertTrue(content.contains("user said: hi"))
    XCTAssertTrue(content.contains("user said: anything new?"))
}
```

- [ ] **Step 16.2 [VERIFY]: Run the test — it should fail**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter ConversationManagerTests/test_respond_appendsJournalEntryPerTurn 2>&1 | tail -15
```

Expected: failure — no journal file exists yet.

- [ ] **Step 16.3 [CC]: Update `ConversationManager` to call the writer and track turn numbers**

`b0tKit/Sources/b0tCore/ConversationManager.swift`:

```swift
import Foundation
import FoundationModels
import b0tBrain

public actor ConversationManager {
    private let bot: Bot
    private let store: BotStore
    private let client: any LanguageModelClient
    private let clock: any Clock
    private let assembler: ContextAssembler
    private let executor: Executor
    private let journalWriter: JournalWriter

    private var nextTurnNumber: Int = 1
    private var didLoadTurnNumber: Bool = false

    public init(
        bot: Bot,
        store: BotStore,
        client: any LanguageModelClient,
        clock: any Clock = SystemClock()
    ) {
        self.bot = bot
        self.store = store
        self.client = client
        self.clock = clock
        self.assembler = ContextAssembler(bot: bot, store: store)
        self.executor = Executor(bot: bot, store: store)
        self.journalWriter = JournalWriter(bot: bot, store: store, clock: clock)
    }

    public func respond(to userPrompt: String) async throws -> ConversationResponse {
        if !didLoadTurnNumber {
            nextTurnNumber = await loadNextTurnNumber()
            didLoadTurnNumber = true
        }
        let turnNumber = nextTurnNumber
        nextTurnNumber += 1

        let context = try await assembler.assemble(
            mode: .conversation(userPrompt: userPrompt)
        )
        let response = try await client.generate(
            context: context,
            generating: ConversationResponse.self
        )
        let delta = try await executor.apply(response)
        try await journalWriter.appendConversationTurn(
            prompt: userPrompt,
            response: response,
            stateDelta: delta,
            turnNumber: turnNumber
        )
        return response
    }

    /// Reads the bot's journal directory and returns the next turn number.
    /// Phase 2 simplification: scan today's journal file for "## HH:MM — turn N"
    /// headers, return max(N) + 1, or 1 if none.
    private func loadNextTurnNumber() async -> Int {
        let url = journalWriter.journalURL(for: clock.now())
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return 1 }
        let pattern = "— turn ([0-9]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 1 }
        let range = NSRange(content.startIndex..., in: content)
        var max = 0
        regex.enumerateMatches(in: content, range: range) { match, _, _ in
            guard let match,
                  let nrange = Range(match.range(at: 1), in: content),
                  let n = Int(content[nrange]) else { return }
            if n > max { max = n }
        }
        return max + 1
    }
}
```

- [ ] **Step 16.4 [VERIFY]: Run all tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --no-parallel 2>&1 | tail -10
```

Expected: all tests pass.

- [ ] **Step 16.5 [CC]: Add the journal-tail pane to `DebugBrainView`**

Modify `b0tApp/Sources/Debug/DebugBrainView.swift` to add a journal-tail pane that polls the day's journal file every second and renders the last ~10 entries.

Replace the file with:

```swift
#if DEBUG
import SwiftUI
import b0tCore
import b0tBrain

struct DebugBrainView: View {
    let bot: Bot
    let store: BotStore

    @State private var input: String = ""
    @State private var log: [LogEntry] = []
    @State private var isThinking: Bool = false
    @State private var manager: ConversationManager?
    @State private var modelStatus: ModelStatus = .uninitialized
    @State private var journalTail: String = ""

    private struct LogEntry: Identifiable {
        let id = UUID()
        let role: Role
        let text: String
        enum Role { case user, bot, status }
    }

    private enum ModelStatus {
        case uninitialized
        case live
        case stub(reason: String)
    }

    var body: some View {
        VStack(spacing: 0) {
            modelStatusBanner
            HStack(alignment: .top, spacing: 0) {
                chatPane
                    .frame(maxWidth: .infinity)
                Divider()
                journalPane
                    .frame(maxWidth: .infinity)
            }
            Divider()
            HStack {
                TextField("message", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isThinking || manager == nil)
                    .onSubmit { Task { await send() } }
                Button("send") { Task { await send() } }
                    .disabled(input.isEmpty || isThinking || manager == nil)
            }
            .padding()
        }
        .navigationTitle("debug brain")
        .task { await initializeManager() }
        .task { await pollJournalTail() }
    }

    @ViewBuilder
    private var modelStatusBanner: some View {
        switch modelStatus {
        case .uninitialized:
            Text("initializing model...")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        case .live:
            EmptyView()
        case .stub(let reason):
            Text("stub mode — \(reason)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }

    private var chatPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(log) { entry in
                    Text(entry.text)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(colour(for: entry.role))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
    }

    private var journalPane: some View {
        ScrollView {
            Text(journalTail.isEmpty ? "(journal empty)" : journalTail)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }

    private func colour(for role: LogEntry.Role) -> Color {
        switch role {
        case .user: return .primary
        case .bot: return .accentColor
        case .status: return .secondary
        }
    }

    private func initializeManager() async {
        let forceStub = ProcessInfo.processInfo.arguments.contains("--use-stub-client")

        let client: any LanguageModelClient
        if forceStub {
            client = makeStub()
            modelStatus = .stub(reason: "--use-stub-client launch arg")
        } else {
            do {
                client = try LiveLanguageModelClient()
                modelStatus = .live
            } catch LanguageModelClientError.modelUnavailable {
                client = makeStub()
                modelStatus = .stub(reason: "model unavailable on this device")
            } catch {
                client = makeStub()
                modelStatus = .stub(reason: "init failed: \(error)")
            }
        }

        manager = ConversationManager(bot: bot, store: store, client: client)
    }

    private func makeStub() -> StubLanguageModelClient {
        StubLanguageModelClient { context, _ in
            ConversationResponse(text: "echo: \(context.userPrompt)")
        }
    }

    private func pollJournalTail() async {
        while !Task.isCancelled {
            await refreshJournalTail()
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func refreshJournalTail() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let day = formatter.string(from: Date())
        let url = bot.journal.directoryURL.appendingPathComponent("\(day).md")
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            // Keep the last ~3000 characters — enough to show several entries.
            if content.count <= 3000 {
                journalTail = content
            } else {
                let suffix = content.suffix(3000)
                journalTail = "...\n" + String(suffix)
            }
        }
    }

    private func send() async {
        guard let manager else { return }
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        input = ""
        log.append(LogEntry(role: .user, text: "> \(prompt)"))
        isThinking = true
        defer { isThinking = false }

        do {
            let reply = try await manager.respond(to: prompt)
            log.append(LogEntry(role: .bot, text: reply.text))
            await refreshJournalTail()
        } catch {
            log.append(LogEntry(role: .status, text: "error: \(error)"))
        }
    }
}
#endif
```

- [ ] **Step 16.6 [VERIFY]: Build the app for simulator**

```bash
cd /Users/haydentoppeross/development/b0t
xcrun xcodebuild build \
    -project b0t.xcodeproj \
    -scheme b0t \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug \
    2>&1 | tail -15
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 16.7 [VERIFY]: Manual smoke**

1. Run on simulator, tap "debug brain".
2. Two-pane layout: chat on left, journal-tail on right.
3. Type "hello" → reply appears in chat, journal-tail updates with `## HH:MM — turn 1` entry.
4. Type "again" → reply appears, journal-tail shows turn 2 above turn 1 (since journals are append-bottom; tail shows the bottom-most content).

Actually, journals are append-bottom; the tail shows the *last* characters of the file, which is the *most recent* entry. Verify the behaviour matches.

- [ ] **Step 16.8 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/ConversationManager.swift \
        b0tKit/Tests/b0tCoreTests/ConversationManagerTests.swift \
        b0tApp/Sources/Debug/DebugBrainView.swift
git commit -m "feat(b0tCore): wire JournalWriter into ConversationManager; add journal pane

Each conversation turn now appends an OpenClaw entry to today's journal.
Turn numbering is read from the journal file on first call, then
incremented in actor state. DebugBrainView grows a second pane that
polls the journal file once per second and shows the tail. End of
Phase 2 Slice 4. See spec §7.1, §7.3."
```

---

## Slice 5 — Heartbeat skeleton (manual entry, no BGTask yet)

Goal of this slice: by end of Task 21, `DebugBrainView` has a "fire heartbeat now" button. Tapping it runs a `HeartbeatManager.tick(trigger: .manual)` that assembles a heartbeat-mode prompt, calls the (stub or live) client for a `TickDecision`, applies the Executor, appends a `## HH:MM — heartbeat N` journal entry. No schedule.md interpretation yet, no BGAppRefreshTask yet, no tool calls yet — Slices 6-9 thicken those.

### Task 17: `TickDecision` (full OpenClaw shape)

**Files:**
- Create: `b0tKit/Sources/b0tCore/Decisions/TickDecision.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/DecisionsTests.swift`

- [ ] **Step 17.1 [CC]: Write `TickDecision`**

`b0tKit/Sources/b0tCore/Decisions/TickDecision.swift`:

```swift
import Foundation
import FoundationModels

/// The model's output for a heartbeat tick.
///
/// Maps directly to OpenClaw's six fields (observed/considered/decided/why/acted)
/// plus mood and organUsed. `state_delta` is NOT a field here — it's computed
/// by JournalWriter from Executor side effects (see spec §3 / §5.5).
///
/// `organUsed` is a skill identifier (e.g., "calendar", "mail") indicating which
/// b0t organ engaged this beat, or nil if no skill was involved. Phase 2 ships
/// only the time-awareness tool (Slice 9), so most ticks will have nil here.
@Generable(representNilExplicitlyInGeneratedContent: true)
public struct TickDecision: Sendable, Equatable {
    @Guide(description: "What you noticed at this beat — one sentence.")
    public let observed: String

    @Guide(description: "The actions you considered taking, as labels.")
    public let considered: [String]

    @Guide(description: "Which action you chose — one of the considered labels.")
    public let decided: String

    @Guide(description: "Why you chose that action — one sentence.")
    public let why: String

    @Guide(description: "What you did in concrete terms (e.g., 'noted silently', 'posted to chat').")
    public let acted: String

    @Guide(description: "Your current mood, or nil if no meaningful change.")
    public let mood: MoodTag?

    @Guide(description: "The skill organ used this beat (e.g., 'calendar'), or nil.")
    public let organUsed: String?

    @Guide(description: "Things to remember from this beat.")
    public let memoryObservations: [MemoryObservation]

    public init(
        observed: String,
        considered: [String],
        decided: String,
        why: String,
        acted: String,
        mood: MoodTag? = nil,
        organUsed: String? = nil,
        memoryObservations: [MemoryObservation] = []
    ) {
        self.observed = observed
        self.considered = considered
        self.decided = decided
        self.why = why
        self.acted = acted
        self.mood = mood
        self.organUsed = organUsed
        self.memoryObservations = memoryObservations
    }
}
```

- [ ] **Step 17.2 [CC]: Add equality + default-args tests**

Append to `b0tKit/Tests/b0tCoreTests/DecisionsTests.swift`:

```swift
func test_tickDecision_defaultArguments() {
    let d = TickDecision(
        observed: "afternoon",
        considered: ["pass", "glance_calendar"],
        decided: "pass",
        why: "nothing urgent",
        acted: "noted silently"
    )
    XCTAssertNil(d.mood)
    XCTAssertNil(d.organUsed)
    XCTAssertTrue(d.memoryObservations.isEmpty)
}

func test_tickDecision_equality() {
    let a = TickDecision(
        observed: "x", considered: ["y"], decided: "y", why: "z", acted: "w",
        mood: .attentive, organUsed: "calendar",
        memoryObservations: [MemoryObservation(about: "a", what: "b", importance: .low)]
    )
    let b = TickDecision(
        observed: "x", considered: ["y"], decided: "y", why: "z", acted: "w",
        mood: .attentive, organUsed: "calendar",
        memoryObservations: [MemoryObservation(about: "a", what: "b", importance: .low)]
    )
    XCTAssertEqual(a, b)
}
```

- [ ] **Step 17.3 [VERIFY]: Run the tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter DecisionsTests 2>&1 | tail -10
```

Expected: 2 new tests pass; existing tests still pass.

- [ ] **Step 17.4 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Decisions/TickDecision.swift \
        b0tKit/Tests/b0tCoreTests/DecisionsTests.swift
git commit -m "feat(b0tCore): TickDecision — heartbeat decision @Generable

Six OpenClaw fields plus mood, organUsed, memoryObservations. state_delta
is intentionally NOT a model output — it's computed by JournalWriter from
Executor side effects. Default-arg init keeps optional fields ergonomic.
See spec §6."
```

---

### Task 18: `ContextAssembler.heartbeat` mode (identity + memory only — no schedule yet)

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Context/ContextAssembler.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift`

**Why now:** A skeleton heartbeat path is enough to drive Slice 5's tests. Slice 6 (Task 23) extends it to load `actions.md`; Slice 7 (Task 28) prepends the missed-beat note.

- [ ] **Step 18.1 [CC]: Add the failing test**

Append to `b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift`:

```swift
func test_heartbeat_includesIdentityAndMemoryAndTriggerContext() async throws {
    let bot = try await loadCanonicalBot()
    let assembler = ContextAssembler(bot: bot, store: BotStore())
    let context = try await assembler.assemble(
        mode: .heartbeat(trigger: .scheduled, missedGap: nil)
    )

    XCTAssertTrue(context.systemInstructions.contains("b0t-01"))
    XCTAssertTrue(context.loadedFiles.contains("identity/core.md"))
    XCTAssertTrue(context.loadedFiles.contains("identity/principles.md"))
    XCTAssertTrue(context.loadedFiles.contains("memory/core.md"))
    XCTAssertTrue(context.userPrompt.contains("scheduled"),
                  "heartbeat prompt should render the trigger kind")
}

func test_heartbeat_manualTriggerRendersDifferently() async throws {
    let bot = try await loadCanonicalBot()
    let assembler = ContextAssembler(bot: bot, store: BotStore())
    let context = try await assembler.assemble(
        mode: .heartbeat(trigger: .manual, missedGap: nil)
    )

    XCTAssertTrue(context.userPrompt.contains("manual"))
}
```

- [ ] **Step 18.2 [VERIFY]: Run the test — it should fail (the heartbeat branch fatalErrors)**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter ContextAssemblerTests/test_heartbeat 2>&1 | tail -15
```

Expected: failure (or crash if running serially).

- [ ] **Step 18.3 [CC]: Implement the `.heartbeat` branch in `ContextAssembler`**

Replace the `assemble(mode:)` switch and add a private method:

```swift
public func assemble(mode: AssemblyMode) async throws -> AssembledContext {
    switch mode {
    case .conversation(let userPrompt):
        return try await assembleConversation(userPrompt: userPrompt)
    case .heartbeat(let trigger, let missedGap):
        return try await assembleHeartbeat(trigger: trigger, missedGap: missedGap)
    case .fallback:
        // Slice 10 implements this branch.
        fatalError("fallback mode not implemented until Slice 10")
    }
}

private func assembleHeartbeat(
    trigger: TickTrigger,
    missedGap: Duration?
) async throws -> AssembledContext {
    let identityCore = try await bot.identity.core
    let identityPrinciples = try await bot.identity.principles
    let memoryCore = try await bot.memory.core

    let identityText = [identityCore.prose, identityPrinciples.prose].joined(separator: "\n\n")
    let memoryText = memoryCore.prose

    let systemInstructions = """
    you are the b0t named '\(bot.rootURL.lastPathComponent)'.

    identity:
    \(identityText)

    what you remember about the user:
    \(memoryText)
    """

    let triggerLine = "you woke from a \(trigger.rawValue) beat."
    let userPrompt: String
    if let missedGap {
        userPrompt = """
        \(triggerLine)
        gap since last beat: ~\(Int(missedGap.timeInterval / 60)) minutes.

        decide what to do at this beat. produce a TickDecision following the OpenClaw fields.
        """
    } else {
        userPrompt = """
        \(triggerLine)

        decide what to do at this beat. produce a TickDecision following the OpenClaw fields.
        """
    }

    let identityTokens = TokenEstimator.estimate(identityText)
    let memoryTokens = TokenEstimator.estimate(memoryText)
    let promptTokens = TokenEstimator.estimate(userPrompt)
    let total = identityTokens + memoryTokens + promptTokens

    let breakdown = [
        "identity": identityTokens,
        "memory": memoryTokens,
        "userPrompt": promptTokens,
    ]
    let budget = TokenBudget(
        estimated: total,
        limit: Self.limit,
        breakdown: breakdown,
        didFallBackToDigest: false
    )

    Self.logger.debug("assembled heartbeat prompt — total: \(total), trigger: \(trigger.rawValue)")

    return AssembledContext(
        systemInstructions: systemInstructions,
        userPrompt: userPrompt,
        tools: [],
        budget: budget,
        loadedFiles: [
            "identity/core.md",
            "identity/principles.md",
            "memory/core.md",
        ]
    )
}
```

Add a small helper extension at the bottom of the file (after the struct):

```swift
private extension Duration {
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return Double(seconds) + Double(attoseconds) / 1e18
    }
}
```

- [ ] **Step 18.4 [VERIFY]: Run the tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter ContextAssemblerTests 2>&1 | tail -15
```

Expected: 5 tests pass.

- [ ] **Step 18.5 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Context/ContextAssembler.swift \
        b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift
git commit -m "feat(b0tCore): ContextAssembler.heartbeat mode (skeleton — identity + memory)

Slice-5 heartbeat-mode prompt: same identity/memory baseline as conversation,
plus a trigger-line + missed-gap render in the user prompt. actions.md
inclusion lands in Slice 6 Task 23. Missed-beat note prefix lands in
Slice 7 Task 28. See spec §7.2."
```

---

### Task 19: `HeartbeatManager` skeleton + `TickResult` + `SuppressionReason` + `Executor.apply(TickDecision)`

**Files:**
- Create: `b0tKit/Sources/b0tCore/Support/TickResult.swift`
- Create: `b0tKit/Sources/b0tCore/HeartbeatManager.swift`
- Modify: `b0tKit/Sources/b0tCore/Apply/Executor.swift`
- Create: `b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/ExecutorTests.swift`

**Why now:** The manager only has the manual-trigger path so far. Wiring the executor's TickDecision overload here keeps the journal-writer task (next) tightly scoped.

- [ ] **Step 19.1 [CC]: Write `TickResult` and `SuppressionReason`**

`b0tKit/Sources/b0tCore/Support/TickResult.swift`:

```swift
import Foundation

/// The outcome of one heartbeat tick attempt.
///
/// `.decided` carries the model's TickDecision (already applied by Executor
/// and journaled).
///
/// `.suppressed` indicates the manager declined to call the model — most
/// commonly during quiet hours (Slice 6 Task 24) or when the model was
/// unavailable.
///
/// `.errored` indicates the model call or executor write failed; the manager
/// has logged an error journal entry but hasn't propagated the error to the
/// caller (because heartbeats are best-effort).
public enum TickResult: Sendable, Equatable {
    case decided(TickDecision)
    case suppressed(reason: SuppressionReason)
    case errored(message: String)
}

public enum SuppressionReason: String, Sendable, Equatable {
    case quietHours
    case modelUnavailable
}
```

- [ ] **Step 19.2 [CC]: Add `Executor.apply(_ decision: TickDecision)`**

Append to `b0tKit/Sources/b0tCore/Apply/Executor.swift` (inside the struct):

```swift
public func apply(_ decision: TickDecision) async throws -> StateDelta {
    let persistable = decision.memoryObservations.filter { $0.importance != .low }
    for observation in decision.memoryObservations where observation.importance == .low {
        Self.logger.debug("memory observation (low, not persisted): \(observation.about) — \(observation.what)")
    }

    var writtenFiles: Set<URL> = []
    if !persistable.isEmpty {
        let recentURL = bot.memory.recentURL
        let existing = try await bot.memory.recent
        let newProse = prependObservations(persistable, to: existing.prose)
        let updated = existing.replacingProse(with: newProse)
        try await store.write(updated)
        writtenFiles.insert(recentURL)
    }

    // Slice-5 heuristic for "would notify" capture: if the acted text begins
    // with "post" or "notify" (case-insensitive), treat it as user-facing
    // intent. Phase 4 replaces this heuristic with an explicit shouldNotify
    // field on TickDecision.
    let lowered = decision.acted.lowercased()
    let wouldNotify: String? = (
        lowered.hasPrefix("post") || lowered.hasPrefix("notify")
    ) ? decision.acted : nil

    return StateDelta(writtenFiles: writtenFiles, wouldNotifyText: wouldNotify)
}
```

- [ ] **Step 19.3 [CC]: Add `Executor` test for the TickDecision overload**

Append to `b0tKit/Tests/b0tCoreTests/ExecutorTests.swift`:

```swift
func test_apply_tickDecision_capturesWouldNotifyText() async throws {
    let bot = try await loadCanonicalBotInTempCopy()
    let store = BotStore()
    let executor = Executor(bot: bot, store: store)

    let decision = TickDecision(
        observed: "deadline approaching",
        considered: ["pass", "notify_user"],
        decided: "notify_user",
        why: "deadline within 30 minutes",
        acted: "post to chat: vendor call in 30 minutes",
        mood: .attentive
    )
    let delta = try await executor.apply(decision)

    XCTAssertEqual(delta.wouldNotifyText, "post to chat: vendor call in 30 minutes")
}

func test_apply_tickDecision_silentActedDoesNotCaptureNotify() async throws {
    let bot = try await loadCanonicalBotInTempCopy()
    let store = BotStore()
    let executor = Executor(bot: bot, store: store)

    let decision = TickDecision(
        observed: "afternoon",
        considered: ["pass"],
        decided: "pass",
        why: "nothing urgent",
        acted: "noted silently"
    )
    let delta = try await executor.apply(decision)

    XCTAssertNil(delta.wouldNotifyText)
}
```

- [ ] **Step 19.4 [CC]: Write the failing `HeartbeatManager` test**

`b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift`:

```swift
import XCTest
import FoundationModels
@testable import b0tCore
@testable import b0tBrain

final class HeartbeatManagerTests: XCTestCase {
    final class FixedClock: Clock, @unchecked Sendable {
        var date: Date
        init(_ date: Date) { self.date = date }
        func now() -> Date { date }
    }

    func test_tick_manualTrigger_callsClient_returnsDecided() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()
        let stub = StubLanguageModelClient { _, _ in
            TickDecision(
                observed: "afternoon",
                considered: ["pass", "glance_calendar"],
                decided: "pass",
                why: "nothing urgent",
                acted: "noted silently",
                mood: .attentive
            )
        }
        let date = ISO8601DateFormatter().date(from: "2026-05-01T14:32:00Z")!
        let manager = HeartbeatManager(
            bot: bot,
            store: store,
            client: stub,
            clock: FixedClock(date)
        )

        let result = try await manager.tick(trigger: .manual)

        switch result {
        case .decided(let d):
            XCTAssertEqual(d.decided, "pass")
            XCTAssertEqual(d.mood, .attentive)
        case .suppressed, .errored:
            XCTFail("expected .decided, got \(result)")
        }
    }

    private func loadCanonicalBotInTempCopy() async throws -> Bot {
        let fixture = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/canonical-bot")
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: fixture, to: temp)
        addTeardownBlock { try? FileManager.default.removeItem(at: temp) }
        let store = BotStore()
        return try await store.load(at: temp)
    }
}
```

- [ ] **Step 19.5 [VERIFY]: Run the test — it should fail to build**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter HeartbeatManagerTests 2>&1 | tail -20
```

Expected: build error referencing `HeartbeatManager`.

- [ ] **Step 19.6 [CC]: Implement `HeartbeatManager` skeleton**

`b0tKit/Sources/b0tCore/HeartbeatManager.swift`:

```swift
import Foundation
import FoundationModels
import b0tBrain
import OSLog

/// Orchestrates one heartbeat tick: assemble context → call client → apply
/// executor → append journal entry.
///
/// Slice 5 (this file): manual-trigger path only. No BGAppRefreshTask, no
/// schedule.md interpretation, no missed-beat detection.
///
/// Slice 6 (Task 24-25): adds quiet-hours suppression and actions.md prose
/// injection. Slice 7 (Task 27): adds missed-beat detection. Slice 8 (Task 30-32):
/// adds register/scheduleNext/BGAppRefreshTask wiring + DEBUG timer fallback.
public actor HeartbeatManager {
    private let bot: Bot
    private let store: BotStore
    private let client: any LanguageModelClient
    private let clock: any Clock
    private let assembler: ContextAssembler
    private let executor: Executor
    private let journalWriter: JournalWriter

    private var nextBeatNumber: Int = 1
    private var didLoadBeatNumber: Bool = false

    private static let logger = Logger(subsystem: "com.toppeross.b0t.b0tCore", category: "HeartbeatManager")

    public init(
        bot: Bot,
        store: BotStore,
        client: any LanguageModelClient,
        clock: any Clock = SystemClock()
    ) {
        self.bot = bot
        self.store = store
        self.client = client
        self.clock = clock
        self.assembler = ContextAssembler(bot: bot, store: store)
        self.executor = Executor(bot: bot, store: store)
        self.journalWriter = JournalWriter(bot: bot, store: store, clock: clock)
    }

    public func tick(trigger: TickTrigger) async throws -> TickResult {
        if !didLoadBeatNumber {
            nextBeatNumber = await loadNextBeatNumber()
            didLoadBeatNumber = true
        }
        let beatNumber = nextBeatNumber
        nextBeatNumber += 1

        do {
            let context = try await assembler.assemble(
                mode: .heartbeat(trigger: trigger, missedGap: nil)
            )
            let decision = try await client.generate(
                context: context,
                generating: TickDecision.self
            )
            let delta = try await executor.apply(decision)
            try await journalWriter.appendTick(
                decision: decision,
                stateDelta: delta,
                beatNumber: beatNumber
            )
            return .decided(decision)
        } catch LanguageModelClientError.modelUnavailable {
            try? await journalWriter.appendSuppressed(
                reason: .modelUnavailable,
                beatNumber: beatNumber
            )
            return .suppressed(reason: .modelUnavailable)
        } catch {
            Self.logger.error("heartbeat tick failed: \(String(describing: error))")
            // Slice 10 wires appendError; for now just log and surface.
            return .errored(message: String(describing: error))
        }
    }

    private func loadNextBeatNumber() async -> Int {
        let url = journalWriter.journalURL(for: clock.now())
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return 1 }
        let pattern = "— heartbeat ([0-9]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 1 }
        let range = NSRange(content.startIndex..., in: content)
        var max = 0
        regex.enumerateMatches(in: content, range: range) { match, _, _ in
            guard let match,
                  let nrange = Range(match.range(at: 1), in: content),
                  let n = Int(content[nrange]) else { return }
            if n > max { max = n }
        }
        return max + 1
    }
}
```

Note: `journalWriter.appendTick` and `appendSuppressed` don't exist yet — they're added in Task 20.

- [ ] **Step 19.7 [VERIFY]: Build — should fail referencing missing methods**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift build 2>&1 | tail -10
```

Expected: build error referencing `appendTick` and `appendSuppressed`.

- [ ] **Step 19.8 [CC]: Add stub implementations to `JournalWriter` so HeartbeatManager compiles; real implementations land in Task 20**

Append to `b0tKit/Sources/b0tCore/Apply/JournalWriter.swift`:

```swift
public func appendTick(
    decision: TickDecision,
    stateDelta: StateDelta,
    beatNumber: Int
) async throws {
    // Real impl in Task 20.
    _ = decision; _ = stateDelta; _ = beatNumber
    throw NSError(domain: "JournalWriter", code: -1, userInfo: [NSLocalizedDescriptionKey: "appendTick not yet implemented"])
}

public func appendSuppressed(
    reason: SuppressionReason,
    beatNumber: Int
) async throws {
    // Real impl in Slice 6 Task 24.
    _ = reason; _ = beatNumber
    throw NSError(domain: "JournalWriter", code: -1, userInfo: [NSLocalizedDescriptionKey: "appendSuppressed not yet implemented"])
}
```

- [ ] **Step 19.9 [VERIFY]: Build succeeds; HeartbeatManagerTests fails because appendTick throws**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift build 2>&1 | tail -10
swift test --filter HeartbeatManagerTests 2>&1 | tail -10
swift test --filter ExecutorTests 2>&1 | tail -10
```

Expected: build succeeds. ExecutorTests' new tests pass. HeartbeatManagerTests fails on the appendTick stub (which is what the next task fixes).

- [ ] **Step 19.10 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Support/TickResult.swift \
        b0tKit/Sources/b0tCore/HeartbeatManager.swift \
        b0tKit/Sources/b0tCore/Apply/Executor.swift \
        b0tKit/Sources/b0tCore/Apply/JournalWriter.swift \
        b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift \
        b0tKit/Tests/b0tCoreTests/ExecutorTests.swift
git commit -m "feat(b0tCore): HeartbeatManager skeleton + Executor.apply(TickDecision)

Manual-trigger heartbeat path: assemble → client → executor → journal stub.
Adds TickResult enum (.decided / .suppressed / .errored), SuppressionReason
(.quietHours / .modelUnavailable), Executor's TickDecision overload with
heuristic wouldNotifyText capture. Beat-number tracking mirrors the turn
counter pattern. JournalWriter.appendTick and appendSuppressed are placeholder
throwers; real impls land in Task 20 and Task 24. See spec §5.2, §5.5, §7.2."
```

---

### Task 20: `JournalWriter.appendTick` (real implementation) + `HeartbeatManagerTests` end-to-end

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Apply/JournalWriter.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift`

- [ ] **Step 20.1 [CC]: Add the byte-exact test for `appendTick`**

Append to `b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift`:

```swift
func test_appendTick_writesByteExactOpenClawEntry() async throws {
    let bot = try await loadCanonicalBotInTempCopy()
    let store = BotStore()

    let date = ISO8601DateFormatter().date(from: "2026-05-01T14:32:00Z")!
    let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

    let decision = TickDecision(
        observed: "schedule wake; been 2h since last beat",
        considered: ["quiet_check", "glance_calendar", "pass"],
        decided: "glance_calendar",
        why: "afternoon, calendar skill enabled, deadline today",
        acted: "noted upcoming meeting silently",
        mood: .attentive,
        organUsed: "calendar"
    )
    let stateDelta = StateDelta(writtenFiles: [bot.memory.recentURL])

    try await writer.appendTick(
        decision: decision,
        stateDelta: stateDelta,
        beatNumber: 247
    )

    let content = try String(contentsOf: writer.journalURL(for: date), encoding: .utf8)
    let expected = """
    ---
    date: 2026-05-01
    ---

    ## 14:32 — heartbeat 247

    **observed:** schedule wake; been 2h since last beat
    **considered:** quiet_check, glance_calendar, pass
    **decided:** glance_calendar
    **why:** afternoon, calendar skill enabled, deadline today
    **acted:** noted upcoming meeting silently
    **mood:** attentive
    **organ_used:** calendar
    **state_delta:** memory/recent.md

    """
    XCTAssertEqual(content, expected)
}
```

- [ ] **Step 20.2 [CC]: Replace the stub `appendTick` with the real implementation**

In `b0tKit/Sources/b0tCore/Apply/JournalWriter.swift`, replace the placeholder body:

```swift
public func appendTick(
    decision: TickDecision,
    stateDelta: StateDelta,
    beatNumber: Int
) async throws {
    let date = clock.now()
    let timeString = Self.timeString(for: date)
    let stateDeltaText = Self.formatStateDelta(stateDelta, bot: bot)

    var lines: [String] = [
        "## \(timeString) — heartbeat \(beatNumber)",
        "",
        "**observed:** \(decision.observed)",
        "**considered:** \(decision.considered.joined(separator: ", "))",
        "**decided:** \(decision.decided)",
        "**why:** \(decision.why)",
        "**acted:** \(decision.acted)",
    ]

    if let mood = decision.mood {
        lines.append("**mood:** \(mood.rawValue)")
    }
    if let organ = decision.organUsed {
        lines.append("**organ_used:** \(organ)")
    }
    if !decision.memoryObservations.isEmpty {
        lines.append("**memory_observations:**")
        for obs in decision.memoryObservations {
            lines.append("- (\(obs.importance.rawValue)) \(obs.about): \(obs.what)")
        }
    }
    lines.append("**state_delta:** \(stateDeltaText)")

    let entry = lines.joined(separator: "\n")
    try await appendRaw(entry, for: date)
}
```

- [ ] **Step 20.3 [CC]: Update `HeartbeatManagerTests` with the end-to-end assertion**

Append to `b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift`:

```swift
func test_tick_writesJournalEntryAndAppliesObservations() async throws {
    let bot = try await loadCanonicalBotInTempCopy()
    let store = BotStore()
    let stub = StubLanguageModelClient { _, _ in
        TickDecision(
            observed: "afternoon",
            considered: ["pass", "store_for_later"],
            decided: "store_for_later",
            why: "user mentioned a deadline",
            acted: "noted silently",
            memoryObservations: [
                MemoryObservation(about: "deadlines", what: "vendor by friday", importance: .medium)
            ]
        )
    }
    let date = ISO8601DateFormatter().date(from: "2026-05-01T15:00:00Z")!
    let manager = HeartbeatManager(
        bot: bot, store: store, client: stub, clock: FixedClock(date)
    )

    _ = try await manager.tick(trigger: .manual)

    // Journal entry written.
    let journalURL = bot.journal.directoryURL.appendingPathComponent("2026-05-01.md")
    let journalContent = try String(contentsOf: journalURL, encoding: .utf8)
    XCTAssertTrue(journalContent.contains("## 15:00 — heartbeat 1"))
    XCTAssertTrue(journalContent.contains("decided:** store_for_later"))

    // Memory observation persisted.
    let recent = try await bot.memory.recent
    XCTAssertTrue(recent.prose.contains("vendor by friday"))
}
```

- [ ] **Step 20.4 [VERIFY]: Run all the relevant tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter JournalWriterTests 2>&1 | tail -10
swift test --filter HeartbeatManagerTests 2>&1 | tail -10
swift test --no-parallel 2>&1 | tail -10
```

Expected: all pass.

- [ ] **Step 20.5 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Apply/JournalWriter.swift \
        b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift \
        b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift
git commit -m "feat(b0tCore): JournalWriter.appendTick — real OpenClaw heartbeat entries

Replaces the Task-19 stub with the byte-exact heartbeat entry shape per
spec §7.3. End-to-end HeartbeatManager test asserts the journal contains
the expected entry AND the executor wrote memory observations to
memory/recent.md. See spec §7.2, §7.3."
```

---

### Task 21: "Fire heartbeat now" button in `DebugBrainView`

**Files:**
- Modify: `b0tApp/Sources/Debug/DebugBrainView.swift`

**Why now:** End of Slice 5. After this task, manual smoke proves the heartbeat path works on a running app.

- [ ] **Step 21.1 [CC]: Add a `HeartbeatManager` to `DebugBrainView` and a button to fire it**

In `b0tApp/Sources/Debug/DebugBrainView.swift`, add a new `@State` property and update the body:

Add to `@State` block:

```swift
@State private var heartbeat: HeartbeatManager?
@State private var isHeartbeating: Bool = false
```

In `initializeManager()`, after creating `manager`, also create `heartbeat`:

```swift
manager = ConversationManager(bot: bot, store: store, client: client)
heartbeat = HeartbeatManager(bot: bot, store: store, client: client)
```

In the `body` HStack at the bottom (with the TextField and "send" button), add a third button:

```swift
HStack {
    TextField("message", text: $input)
        .textFieldStyle(.roundedBorder)
        .disabled(isThinking || manager == nil)
        .onSubmit { Task { await send() } }
    Button("send") { Task { await send() } }
        .disabled(input.isEmpty || isThinking || manager == nil)
    Button("♥") { Task { await fireHeartbeat() } }
        .disabled(isHeartbeating || heartbeat == nil)
        .help("fire heartbeat now")
}
.padding()
```

Add the `fireHeartbeat` method:

```swift
private func fireHeartbeat() async {
    guard let heartbeat else { return }
    isHeartbeating = true
    defer { isHeartbeating = false }
    log.append(LogEntry(role: .status, text: "♥ firing heartbeat..."))
    do {
        let result = try await heartbeat.tick(trigger: .manual)
        switch result {
        case .decided(let d):
            log.append(LogEntry(role: .status, text: "♥ \(d.decided): \(d.acted)"))
        case .suppressed(let reason):
            log.append(LogEntry(role: .status, text: "♥ suppressed (\(reason.rawValue))"))
        case .errored(let msg):
            log.append(LogEntry(role: .status, text: "♥ errored: \(msg)"))
        }
        await refreshJournalTail()
    } catch {
        log.append(LogEntry(role: .status, text: "♥ tick threw: \(error)"))
    }
}
```

- [ ] **Step 21.2 [VERIFY]: Build the app for simulator**

```bash
cd /Users/haydentoppeross/development/b0t
xcrun xcodebuild build \
    -project b0t.xcodeproj \
    -scheme b0t \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug \
    2>&1 | tail -15
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 21.3 [VERIFY]: Manual smoke**

1. Run on simulator. Tap "debug brain". Stub mode banner shows.
2. Tap the ♥ button.
3. Status line in the chat shows "♥ firing heartbeat..." then "♥ pass: noted silently" (or whatever the stub returns — wait, the stub in DebugBrainView returns ConversationResponse, not TickDecision; the heartbeat path needs a stub that returns TickDecision when asked for it).

The current `makeStub()` always returns ConversationResponse. Update it to handle both types:

```swift
private func makeStub() -> StubLanguageModelClient {
    StubLanguageModelClient { context, outputType in
        if outputType == ConversationResponse.self {
            return ConversationResponse(text: "echo: \(context.userPrompt)")
        } else if outputType == TickDecision.self {
            return TickDecision(
                observed: "manual tick",
                considered: ["pass"],
                decided: "pass",
                why: "stub mode",
                acted: "noted silently"
            )
        } else {
            preconditionFailure("stub does not handle \(outputType)")
        }
    }
}
```

Re-run the smoke. Tap ♥; status line should now read "♥ pass: noted silently" and the journal-tail pane should grow a `## HH:MM — heartbeat 1` entry.

- [ ] **Step 21.4 [VERIFY]: All tests still pass**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --no-parallel 2>&1 | tail -10
```

Expected: all pass.

- [ ] **Step 21.5 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tApp/Sources/Debug/DebugBrainView.swift
git commit -m "feat(b0tApp): DebugBrainView ♥ button — fire heartbeat manually

The view now constructs a HeartbeatManager alongside the conversation
manager and exposes a heart-shaped button that calls tick(trigger: .manual).
Updates the in-view stub to handle both ConversationResponse and
TickDecision request types. End of Phase 2 Slice 5 — heartbeat skeleton
runs end-to-end on a running app, journal grows visibly. See spec §9.4."
```

---

## Slice 6 — `schedule.md` and `actions.md` interpretation

Goal of this slice: by end of Task 25, `HeartbeatSchedule` is parsed from `heartbeat/schedule.md` (BPM, quiet hours, event triggers). The heartbeat-mode prompt includes the full body of `heartbeat/actions.md`. Quiet hours suppress the model call and journal a `.suppressed` entry. `notification_budget_per_day` from `actions.md` frontmatter is read and enforced.

### Task 22: `HeartbeatSchedule` + `EventTriggerKind` parser

**Files:**
- Create: `b0tKit/Sources/b0tCore/Schedule/EventTriggerKind.swift`
- Create: `b0tKit/Sources/b0tCore/Schedule/HeartbeatSchedule.swift`
- Create: `b0tKit/Tests/b0tCoreTests/HeartbeatScheduleTests.swift`

- [ ] **Step 22.1 [CC]: Write `EventTriggerKind`**

`b0tKit/Sources/b0tCore/Schedule/EventTriggerKind.swift`:

```swift
import Foundation

/// Event-trigger keys recognized in `heartbeat/schedule.md` frontmatter.
///
/// Slice 6 parses the list but does not wire actual event triggers — only
/// `.scheduled` ticks fire in Phase 2. Phase 4+ adds CLLocationManager,
/// EKEventStore observation, app lifecycle, and notification observation
/// hooks that fire heartbeats with the corresponding trigger kind.
public enum EventTriggerKind: String, Sendable, Equatable, CaseIterable {
    case locationChangeSignificant = "location_change_significant"
    case calendarEventApproaching30min = "calendar_event_approaching_30min"
    case appForegrounded = "app_foregrounded"
    case notificationReceived = "notification_received"
}
```

- [ ] **Step 22.2 [CC]: Write the failing test**

`b0tKit/Tests/b0tCoreTests/HeartbeatScheduleTests.swift`:

```swift
import XCTest
import FoundationModels
@testable import b0tCore
@testable import b0tBrain

final class HeartbeatScheduleTests: XCTestCase {
    func test_parse_canonicalScheduleFile_extractsAllFields() async throws {
        let bot = try await loadCanonicalBot()
        let scheduleFile = try await bot.heartbeat.schedule
        let schedule = try HeartbeatSchedule.parse(scheduleFile)

        XCTAssertEqual(schedule.bpm, 30)
        XCTAssertNotNil(schedule.quietHours)
        XCTAssertEqual(schedule.quietHours?.lowerBound, ClockTime(hour: 22, minute: 0))
        XCTAssertEqual(schedule.quietHours?.upperBound, ClockTime(hour: 6, minute: 30))
        XCTAssertEqual(schedule.eventTriggers, Set([
            .locationChangeSignificant,
            .calendarEventApproaching30min,
            .appForegrounded,
            .notificationReceived,
        ]))
        XCTAssertTrue(schedule.mutable)
    }

    func test_bpmInterval_isFifteenMinutes_at_BPM_30() {
        let schedule = HeartbeatSchedule(
            bpm: 30,
            quietHours: nil,
            eventTriggers: [],
            mutable: true
        )
        XCTAssertEqual(schedule.bpmInterval, .seconds(30 * 60))
    }

    func test_bpmInterval_isNil_at_BPM_0() {
        let schedule = HeartbeatSchedule(
            bpm: 0, quietHours: nil, eventTriggers: [], mutable: true
        )
        XCTAssertNil(schedule.bpmInterval)
    }

    func test_isQuietHours_normalRange_dayStart() {
        let schedule = HeartbeatSchedule(
            bpm: 30,
            quietHours: ClockTime(hour: 9, minute: 0)...ClockTime(hour: 17, minute: 0),
            eventTriggers: [], mutable: true
        )
        let inside = makeDate(year: 2026, month: 5, day: 1, hour: 10, minute: 30)
        let before = makeDate(year: 2026, month: 5, day: 1, hour: 8, minute: 0)
        let after = makeDate(year: 2026, month: 5, day: 1, hour: 17, minute: 1)
        XCTAssertTrue(schedule.isQuietHours(at: inside))
        XCTAssertFalse(schedule.isQuietHours(at: before))
        XCTAssertFalse(schedule.isQuietHours(at: after))
    }

    func test_isQuietHours_overnight_range() {
        // 22:00 to 06:30 — the canonical case. midnight rollover.
        let schedule = HeartbeatSchedule(
            bpm: 30,
            quietHours: ClockTime(hour: 22, minute: 0)...ClockTime(hour: 6, minute: 30),
            eventTriggers: [], mutable: true
        )
        let lateEvening = makeDate(year: 2026, month: 5, day: 1, hour: 23, minute: 0)
        let earlyMorning = makeDate(year: 2026, month: 5, day: 2, hour: 5, minute: 0)
        let midDay = makeDate(year: 2026, month: 5, day: 1, hour: 12, minute: 0)
        XCTAssertTrue(schedule.isQuietHours(at: lateEvening))
        XCTAssertTrue(schedule.isQuietHours(at: earlyMorning))
        XCTAssertFalse(schedule.isQuietHours(at: midDay))
    }

    func test_parse_missingBPM_defaultsTo30() throws {
        // Construct an in-memory BotFile with no bpm key.
        let raw = """
        ---
        quiet_hours: [22:00, 06:30]
        mutable: true
        ---
        # schedule

        body
        """
        let url = URL(fileURLWithPath: "/tmp/schedule.md")
        let file = try BotFile(rawText: raw, fileURL: url)
        let schedule = try HeartbeatSchedule.parse(file)
        XCTAssertEqual(schedule.bpm, 30, "missing bpm should default to 30")
    }

    private func loadCanonicalBot() async throws -> Bot {
        let fixturesURL = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/canonical-bot")
        let store = BotStore()
        return try await store.load(at: fixturesURL)
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        components.hour = hour; components.minute = minute
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
```

Note: `BotFile(rawText:fileURL:)` is a Phase 1 init; if the actual b0tBrain API uses a different constructor for in-memory files (e.g., reading from disk only), adapt to use `BotStore.read` against a tmp file.

- [ ] **Step 22.3 [VERIFY]: Run the test — it should fail to build**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter HeartbeatScheduleTests 2>&1 | tail -20
```

Expected: build error referencing `HeartbeatSchedule`, `ClockTime`.

- [ ] **Step 22.4 [CC]: Implement `HeartbeatSchedule` and `ClockTime`**

`b0tKit/Sources/b0tCore/Schedule/HeartbeatSchedule.swift`:

```swift
import Foundation
import b0tBrain

/// A simple HH:MM value type for parsing quiet-hours boundaries.
///
/// Conforming to `Comparable` so we can use ranges. We model overnight
/// quiet hours (e.g., 22:00–06:30) by checking inclusion in
/// `[start, 24:00) ∪ [00:00, end]` rather than a literal Swift range.
///
/// Named `ClockTime` (not `TimeOfDay`) to avoid colliding with the
/// `TimeOfDay` bucket enum in `Tools/TimeOfDay.swift`. Spec §5.7
/// matches this name.
public struct ClockTime: Sendable, Equatable, Hashable, Comparable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) {
        precondition(hour >= 0 && hour < 24, "hour out of range")
        precondition(minute >= 0 && minute < 60, "minute out of range")
        self.hour = hour
        self.minute = minute
    }

    public static func < (lhs: ClockTime, rhs: ClockTime) -> Bool {
        if lhs.hour != rhs.hour { return lhs.hour < rhs.hour }
        return lhs.minute < rhs.minute
    }

    public init(from date: Date, in timeZone: TimeZone = TimeZone(identifier: "UTC")!) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
    }
}

/// Heartbeat schedule parsed from `heartbeat/schedule.md` frontmatter.
///
/// Per spec §5.7, this is structurally parsed (drives timing in code). The
/// schedule.md prose is NOT included in the heartbeat prompt — only
/// actions.md is, since actions.md drives per-beat behaviour.
///
/// Quiet-hours range is inclusive on both ends and supports overnight ranges
/// (lower bound > upper bound is interpreted as "spans midnight").
///
/// `bpm: 0` means scheduled beats are off entirely; event triggers still fire.
public struct HeartbeatSchedule: Sendable, Equatable {
    public let bpm: Int
    public let quietHours: ClosedRange<ClockTime>?
    public let eventTriggers: Set<EventTriggerKind>
    public let mutable: Bool

    public init(
        bpm: Int,
        quietHours: ClosedRange<ClockTime>?,
        eventTriggers: Set<EventTriggerKind>,
        mutable: Bool
    ) {
        self.bpm = bpm
        self.quietHours = quietHours
        self.eventTriggers = eventTriggers
        self.mutable = mutable
    }

    public var bpmInterval: Duration? {
        guard bpm > 0 else { return nil }
        return .seconds(bpm * 60)
    }

    public func isQuietHours(at date: Date) -> Bool {
        guard let range = quietHours else { return false }
        let now = ClockTime(from: date)

        if range.lowerBound <= range.upperBound {
            // Same-day range, e.g., 09:00–17:00.
            return now >= range.lowerBound && now <= range.upperBound
        } else {
            // Overnight range, e.g., 22:00–06:30.
            return now >= range.lowerBound || now <= range.upperBound
        }
    }

    /// Parses a `heartbeat/schedule.md` BotFile.
    ///
    /// Missing fields fall back to defaults (bpm: 30, no quiet hours, no
    /// event triggers, mutable: true) per spec §8 — malformed schedule.md
    /// should not block ticking.
    public static func parse(_ file: BotFile) throws -> HeartbeatSchedule {
        let bpm = (file.frontmatter["heartbeat_bpm"]?.intValue) ?? 30
        let mutable = (file.frontmatter["mutable"]?.boolValue) ?? true

        var quietHours: ClosedRange<ClockTime>? = nil
        if let array = file.frontmatter["quiet_hours"]?.arrayValue,
           array.count == 2,
           let startStr = array[0].stringValue,
           let endStr = array[1].stringValue,
           let start = ClockTime(parsingHHmm: startStr),
           let end = ClockTime(parsingHHmm: endStr) {
            quietHours = start...end
        }

        var eventTriggers: Set<EventTriggerKind> = []
        if let array = file.frontmatter["event_triggers"]?.arrayValue {
            for item in array {
                if let raw = item.stringValue,
                   let kind = EventTriggerKind(rawValue: raw) {
                    eventTriggers.insert(kind)
                }
            }
        }

        return HeartbeatSchedule(
            bpm: bpm, quietHours: quietHours,
            eventTriggers: eventTriggers, mutable: mutable
        )
    }
}

extension ClockTime {
    init?(parsingHHmm s: String) {
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]),
              (0..<24).contains(h),
              (0..<60).contains(m) else {
            return nil
        }
        self.init(hour: h, minute: m)
    }
}

// Convenience accessors on YAMLValue for parsing.
extension YAMLValue {
    var intValue: Int? {
        if case let .int(v) = self { return v }
        if case let .string(s) = self, let v = Int(s) { return v }
        return nil
    }
    var boolValue: Bool? {
        if case let .bool(v) = self { return v }
        return nil
    }
    var stringValue: String? {
        if case let .string(v) = self { return v }
        return nil
    }
    var arrayValue: [YAMLValue]? {
        if case let .array(v) = self { return v }
        return nil
    }
}
```

- [ ] **Step 22.5 [VERIFY]: Run the tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter HeartbeatScheduleTests 2>&1 | tail -15
```

Expected: 6 tests pass. If `BotFile(rawText:fileURL:)` doesn't exist as a constructor, the `test_parse_missingBPM_defaultsTo30` test needs adapting — write the markdown to a temp file and `BotStore.read` it instead.

- [ ] **Step 22.6 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Schedule/ \
        b0tKit/Tests/b0tCoreTests/HeartbeatScheduleTests.swift
git commit -m "feat(b0tCore): HeartbeatSchedule.parse + ClockTime + EventTriggerKind

Parses schedule.md frontmatter into a typed HeartbeatSchedule
(bpm, quiet hours, event triggers, mutable). ClockTime is a comparable
HH:MM value supporting overnight ranges (22:00–06:30) via
'spans-midnight' detection in isQuietHours. Missing fields fall back
to defaults (bpm: 30) per spec §8. See spec §5.7."
```

---

### Task 23: actions.md prose injection in heartbeat-mode `ContextAssembler`

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Context/ContextAssembler.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift`

- [ ] **Step 23.1 [CC]: Add a failing test**

Append to `b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift`:

```swift
func test_heartbeat_includesActionsMdProse() async throws {
    let bot = try await loadCanonicalBot()
    let assembler = ContextAssembler(bot: bot, store: BotStore())
    let context = try await assembler.assemble(
        mode: .heartbeat(trigger: .scheduled, missedGap: nil)
    )

    // actions.md prose contains specific phrases — verify they're in the prompt.
    XCTAssertTrue(
        context.userPrompt.contains("note the time and update mood")
        || context.systemInstructions.contains("note the time and update mood"),
        "actions.md prose should be in the heartbeat prompt"
    )
    XCTAssertTrue(context.loadedFiles.contains("heartbeat/actions.md"))
}
```

- [ ] **Step 23.2 [VERIFY]: Run the test — it should fail**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter ContextAssemblerTests/test_heartbeat_includesActionsMdProse 2>&1 | tail -10
```

Expected: failure — actions.md is not yet read.

- [ ] **Step 23.3 [CC]: Update `assembleHeartbeat` to load and inject actions.md prose**

In `b0tKit/Sources/b0tCore/Context/ContextAssembler.swift`, replace the body of `assembleHeartbeat`:

```swift
private func assembleHeartbeat(
    trigger: TickTrigger,
    missedGap: Duration?
) async throws -> AssembledContext {
    let identityCore = try await bot.identity.core
    let identityPrinciples = try await bot.identity.principles
    let memoryCore = try await bot.memory.core
    let actions = try await bot.heartbeat.actions

    let identityText = [identityCore.prose, identityPrinciples.prose].joined(separator: "\n\n")
    let memoryText = memoryCore.prose
    let actionsText = actions.prose

    let systemInstructions = """
    you are the b0t named '\(bot.rootURL.lastPathComponent)'.

    identity:
    \(identityText)

    what you remember about the user:
    \(memoryText)

    what to do at each beat (your action playbook):
    \(actionsText)
    """

    let triggerLine = "you woke from a \(trigger.rawValue) beat."
    let userPrompt: String
    if let missedGap {
        userPrompt = """
        \(triggerLine)
        gap since last beat: ~\(Int(missedGap.timeInterval / 60)) minutes.

        decide what to do at this beat. produce a TickDecision following the OpenClaw fields.
        """
    } else {
        userPrompt = """
        \(triggerLine)

        decide what to do at this beat. produce a TickDecision following the OpenClaw fields.
        """
    }

    let identityTokens = TokenEstimator.estimate(identityText)
    let memoryTokens = TokenEstimator.estimate(memoryText)
    let actionsTokens = TokenEstimator.estimate(actionsText)
    let promptTokens = TokenEstimator.estimate(userPrompt)
    let total = identityTokens + memoryTokens + actionsTokens + promptTokens

    let breakdown = [
        "identity": identityTokens,
        "memory": memoryTokens,
        "actions": actionsTokens,
        "userPrompt": promptTokens,
    ]
    let budget = TokenBudget(
        estimated: total,
        limit: Self.limit,
        breakdown: breakdown,
        didFallBackToDigest: false
    )

    Self.logger.debug("assembled heartbeat prompt — total: \(total), trigger: \(trigger.rawValue)")

    return AssembledContext(
        systemInstructions: systemInstructions,
        userPrompt: userPrompt,
        tools: [],
        budget: budget,
        loadedFiles: [
            "identity/core.md",
            "identity/principles.md",
            "memory/core.md",
            "heartbeat/actions.md",
        ]
    )
}
```

- [ ] **Step 23.4 [VERIFY]: Run the tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter ContextAssemblerTests 2>&1 | tail -15
```

Expected: all pass.

- [ ] **Step 23.5 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Context/ContextAssembler.swift \
        b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift
git commit -m "feat(b0tCore): include actions.md prose in heartbeat-mode prompt

actions.md is the action playbook that drives per-beat behaviour. Now
included verbatim in the heartbeat-mode system instructions. Token
breakdown gains an 'actions' key. See spec §5.4, §7.2."
```

---

### Task 24: Quiet-hours suppression in `HeartbeatManager` + `JournalWriter.appendSuppressed`

**Files:**
- Modify: `b0tKit/Sources/b0tCore/HeartbeatManager.swift`
- Modify: `b0tKit/Sources/b0tCore/Apply/JournalWriter.swift`
- Create: `b0tKit/Tests/b0tCoreTests/Fixtures/quiet-hours-bot/...` files
- Modify: `b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift`

- [ ] **Step 24.1 [CC]: Build the `quiet-hours-bot` fixture**

The fixture is a bot whose `schedule.md` has quiet hours covering noon UTC (so a tick fired at 12:00 is suppressed). Build the minimum file set the tests need: `identity/{core,principles}.md`, `memory/core.md`, `heartbeat/{schedule,actions}.md`, `_active`-style placeholder is not needed since tests use the directory directly.

`b0tKit/Tests/b0tCoreTests/Fixtures/quiet-hours-bot/identity/core.md`:

```markdown
---
name: quiet-bot
---
# core

I am quiet-bot.
```

`b0tKit/Tests/b0tCoreTests/Fixtures/quiet-hours-bot/identity/principles.md`:

```markdown
---
mutable: true
---
# principles

be honest.
```

`b0tKit/Tests/b0tCoreTests/Fixtures/quiet-hours-bot/memory/core.md`:

```markdown
---
mutable: true
---
# memory core

(empty)
```

`b0tKit/Tests/b0tCoreTests/Fixtures/quiet-hours-bot/memory/recent.md`:

```markdown
---
mutable: true
---
# recent

(empty)
```

`b0tKit/Tests/b0tCoreTests/Fixtures/quiet-hours-bot/heartbeat/schedule.md`:

```markdown
---
heartbeat_bpm: 30
quiet_hours: [11:00, 13:00]
event_triggers: []
mutable: true
---
# schedule

quiet between 11:00 and 13:00 UTC for the test.
```

`b0tKit/Tests/b0tCoreTests/Fixtures/quiet-hours-bot/heartbeat/actions.md`:

```markdown
---
mutable: true
notification_budget_per_day: 5
---
# actions

- pass.
```

- [ ] **Step 24.2 [CC]: Add the failing test**

Append to `b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift`:

```swift
func test_tick_duringQuietHours_suppressesAndJournals() async throws {
    let bot = try await loadFixtureBotInTempCopy(named: "quiet-hours-bot")
    let store = BotStore()

    // Stub raises if called — quiet-hours should suppress before the model is invoked.
    let stub = StubLanguageModelClient { _, _ in
        XCTFail("client must not be called during quiet hours")
        return TickDecision(observed: "", considered: [], decided: "", why: "", acted: "")
    }
    let date = ISO8601DateFormatter().date(from: "2026-05-01T12:00:00Z")!
    let manager = HeartbeatManager(
        bot: bot, store: store, client: stub, clock: FixedClock(date)
    )

    let result = try await manager.tick(trigger: .scheduled)

    switch result {
    case .suppressed(let reason):
        XCTAssertEqual(reason, .quietHours)
    default:
        XCTFail("expected .suppressed(.quietHours), got \(result)")
    }

    // Journal should contain a suppression entry.
    let journalURL = bot.journal.directoryURL.appendingPathComponent("2026-05-01.md")
    let content = try String(contentsOf: journalURL, encoding: .utf8)
    XCTAssertTrue(content.contains("## 12:00 — heartbeat 1 — suppressed"))
    XCTAssertTrue(content.contains("**reason:** quiet hours"))
}

private func loadFixtureBotInTempCopy(named name: String) async throws -> Bot {
    let fixture = Bundle.module.resourceURL!
        .appendingPathComponent("Fixtures/\(name)")
    let temp = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.copyItem(at: fixture, to: temp)
    addTeardownBlock { try? FileManager.default.removeItem(at: temp) }
    let store = BotStore()
    return try await store.load(at: temp)
}
```

- [ ] **Step 24.3 [VERIFY]: Run the test — it should fail (manager doesn't check quiet hours yet)**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter HeartbeatManagerTests/test_tick_duringQuietHours 2>&1 | tail -15
```

Expected: XCTFail("client must not be called during quiet hours") — the stub got called.

- [ ] **Step 24.4 [CC]: Implement `JournalWriter.appendSuppressed` byte-exactly**

Add the byte-exact test first to `JournalWriterTests`:

```swift
func test_appendSuppressed_writesByteExactEntry() async throws {
    let bot = try await loadCanonicalBotInTempCopy()
    let store = BotStore()
    let date = ISO8601DateFormatter().date(from: "2026-05-01T23:14:00Z")!
    let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

    try await writer.appendSuppressed(reason: .quietHours, beatNumber: 248)

    let content = try String(contentsOf: writer.journalURL(for: date), encoding: .utf8)
    let expected = """
    ---
    date: 2026-05-01
    ---

    ## 23:14 — heartbeat 248 — suppressed

    **reason:** quiet hours
    **state_delta:** none

    """
    XCTAssertEqual(content, expected)
}
```

Then replace the placeholder `appendSuppressed` body in `JournalWriter.swift`:

```swift
public func appendSuppressed(
    reason: SuppressionReason,
    beatNumber: Int
) async throws {
    let date = clock.now()
    let timeString = Self.timeString(for: date)

    let reasonText: String
    switch reason {
    case .quietHours: reasonText = "quiet hours"
    case .modelUnavailable: reasonText = "model unavailable"
    }

    let entry = """
    ## \(timeString) — heartbeat \(beatNumber) — suppressed

    **reason:** \(reasonText)
    **state_delta:** none
    """
    try await appendRaw(entry, for: date)
}
```

- [ ] **Step 24.5 [CC]: Update `HeartbeatManager.tick` to check quiet hours**

In `b0tKit/Sources/b0tCore/HeartbeatManager.swift`, modify `tick(trigger:)`:

```swift
public func tick(trigger: TickTrigger) async throws -> TickResult {
    if !didLoadBeatNumber {
        nextBeatNumber = await loadNextBeatNumber()
        didLoadBeatNumber = true
    }
    let beatNumber = nextBeatNumber
    nextBeatNumber += 1

    // Quiet-hours check.
    if let schedule = await loadSchedule(),
       schedule.isQuietHours(at: clock.now()) {
        try? await journalWriter.appendSuppressed(
            reason: .quietHours, beatNumber: beatNumber
        )
        return .suppressed(reason: .quietHours)
    }

    do {
        let context = try await assembler.assemble(
            mode: .heartbeat(trigger: trigger, missedGap: nil)
        )
        let decision = try await client.generate(
            context: context, generating: TickDecision.self
        )
        let delta = try await executor.apply(decision)
        try await journalWriter.appendTick(
            decision: decision, stateDelta: delta, beatNumber: beatNumber
        )
        return .decided(decision)
    } catch LanguageModelClientError.modelUnavailable {
        try? await journalWriter.appendSuppressed(
            reason: .modelUnavailable, beatNumber: beatNumber
        )
        return .suppressed(reason: .modelUnavailable)
    } catch {
        Self.logger.error("heartbeat tick failed: \(String(describing: error))")
        return .errored(message: String(describing: error))
    }
}

private func loadSchedule() async -> HeartbeatSchedule? {
    do {
        let scheduleFile = try await bot.heartbeat.schedule
        return try HeartbeatSchedule.parse(scheduleFile)
    } catch {
        Self.logger.warning("failed to parse schedule.md, falling back to defaults: \(String(describing: error))")
        return nil
    }
}
```

- [ ] **Step 24.6 [VERIFY]: Run all the relevant tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter HeartbeatManagerTests 2>&1 | tail -10
swift test --filter JournalWriterTests 2>&1 | tail -10
swift test --no-parallel 2>&1 | tail -10
```

Expected: all pass.

- [ ] **Step 24.7 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/HeartbeatManager.swift \
        b0tKit/Sources/b0tCore/Apply/JournalWriter.swift \
        b0tKit/Tests/b0tCoreTests/Fixtures/quiet-hours-bot/ \
        b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift \
        b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift
git commit -m "feat(b0tCore): quiet-hours suppression + JournalWriter.appendSuppressed

HeartbeatManager loads HeartbeatSchedule from schedule.md and short-circuits
the model call when isQuietHours(at: now) is true. Suppression writes a
'## HH:MM — heartbeat N — suppressed' entry with reason and state_delta:
none. Adds quiet-hours-bot fixture. See spec §5.7, §7.2, §7.3."
```

---

### Task 25: Notification budget enforcement in `Executor`

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Apply/Executor.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/ExecutorTests.swift`

**Why now:** End of Slice 6. After this task, `actions.md`'s `notification_budget_per_day` is honoured: once the journal contains N `would_notify` entries today, further ticks decline to capture more.

- [ ] **Step 25.1 [CC]: Add the failing test**

Append to `b0tKit/Tests/b0tCoreTests/ExecutorTests.swift`:

```swift
func test_apply_tickDecision_respectsNotificationBudget() async throws {
    let bot = try await loadCanonicalBotInTempCopy()
    let store = BotStore()

    // canonical-bot's actions.md sets notification_budget_per_day: 5.
    // Pre-populate today's journal with 5 'would_notify' entries to exhaust the budget.
    let dayString = makeDayString(for: Date())
    let journalURL = bot.journal.directoryURL.appendingPathComponent("\(dayString).md")
    try FileManager.default.createDirectory(
        at: bot.journal.directoryURL, withIntermediateDirectories: true
    )
    var preexisting = "---\ndate: \(dayString)\n---\n\n"
    for i in 1...5 {
        preexisting += """
        ## 0\(i):00 — heartbeat \(i)

        **observed:** synthetic
        **considered:** notify_user
        **decided:** notify_user
        **why:** synthetic
        **acted:** post to chat: synthetic
        **state_delta:** would_notify: post to chat: synthetic


        """
    }
    try preexisting.data(using: .utf8)!.write(to: journalURL, options: .atomic)

    let executor = Executor(bot: bot, store: store)
    let decision = TickDecision(
        observed: "deadline approaching",
        considered: ["pass", "notify_user"],
        decided: "notify_user",
        why: "deadline within 30 minutes",
        acted: "post to chat: vendor call in 30 minutes"
    )
    let delta = try await executor.apply(decision)

    // Budget exhausted — wouldNotifyText must NOT be captured.
    XCTAssertNil(delta.wouldNotifyText, "budget exhausted, should not capture")
}

private func makeDayString(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.string(from: date)
}
```

- [ ] **Step 25.2 [VERIFY]: Run the test — it should fail (executor doesn't check budget yet)**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter ExecutorTests/test_apply_tickDecision_respectsNotificationBudget 2>&1 | tail -10
```

Expected: failure — executor still captures the would-notify text.

- [ ] **Step 25.3 [CC]: Update `Executor.apply(TickDecision)` to read budget and count today's would-notify entries**

In `b0tKit/Sources/b0tCore/Apply/Executor.swift`, replace the `apply(_ decision: TickDecision)` body:

```swift
public func apply(_ decision: TickDecision) async throws -> StateDelta {
    let persistable = decision.memoryObservations.filter { $0.importance != .low }
    for observation in decision.memoryObservations where observation.importance == .low {
        Self.logger.debug("memory observation (low, not persisted): \(observation.about) — \(observation.what)")
    }

    var writtenFiles: Set<URL> = []
    if !persistable.isEmpty {
        let recentURL = bot.memory.recentURL
        let existing = try await bot.memory.recent
        let newProse = prependObservations(persistable, to: existing.prose)
        let updated = existing.replacingProse(with: newProse)
        try await store.write(updated)
        writtenFiles.insert(recentURL)
    }

    let lowered = decision.acted.lowercased()
    let isNotifyIntent = lowered.hasPrefix("post") || lowered.hasPrefix("notify")
    var wouldNotify: String? = nil

    if isNotifyIntent {
        let budget = (try? await loadNotificationBudgetPerDay()) ?? 5
        let used = (try? countWouldNotifyEntriesToday()) ?? 0
        if used < budget {
            wouldNotify = decision.acted
        } else {
            Self.logger.debug("notification budget exhausted (\(used)/\(budget)); not capturing")
        }
    }

    return StateDelta(writtenFiles: writtenFiles, wouldNotifyText: wouldNotify)
}

private func loadNotificationBudgetPerDay() async throws -> Int {
    let actions = try await bot.heartbeat.actions
    return actions.frontmatter["notification_budget_per_day"]?.intValue ?? 5
}

private func countWouldNotifyEntriesToday() throws -> Int {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")
    let day = formatter.string(from: Date())
    let url = bot.journal.directoryURL.appendingPathComponent("\(day).md")
    let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    let lines = content.split(separator: "\n")
    var count = 0
    for line in lines where line.contains("would_notify:") {
        count += 1
    }
    return count
}
```

(Note: this implementation uses `Date()` rather than the executor's clock — the executor doesn't currently take a Clock. For Slice 6 simplicity that's fine; if tests need deterministic time control over budget tracking, Slice 10 can add a Clock injection.)

- [ ] **Step 25.4 [VERIFY]: Run the tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter ExecutorTests 2>&1 | tail -10
swift test --no-parallel 2>&1 | tail -10
```

Expected: all pass.

- [ ] **Step 25.5 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Apply/Executor.swift \
        b0tKit/Tests/b0tCoreTests/ExecutorTests.swift
git commit -m "feat(b0tCore): Executor respects notification_budget_per_day

When a TickDecision's acted text reads as user-facing notify intent,
Executor reads notification_budget_per_day from actions.md frontmatter
(default 5), counts today's would_notify journal entries, and only
captures wouldNotifyText if used < budget. End of Phase 2 Slice 6.
See spec §7.2."
```

---

## Slice 7 — Missed-beat detection

Goal of this slice: by end of Task 27, the `HeartbeatManager` reads the last journal entry's timestamp and prepends a missed-beat note to the heartbeat-mode prompt when the gap exceeds `bpmInterval × 1.5`. Lets the b0t comment on iOS-skipped beats per design doc §5.4.

### Task 26: `MissedBeatDetector` — read last journal timestamp

**Files:**
- Create: `b0tKit/Sources/b0tCore/Schedule/MissedBeatDetector.swift`
- Create: `b0tKit/Tests/b0tCoreTests/MissedBeatDetectorTests.swift`
- Create: `b0tKit/Tests/b0tCoreTests/Fixtures/journal-with-gaps/2026-05-01.md`

- [ ] **Step 26.1 [CC]: Build the `journal-with-gaps` fixture**

`b0tKit/Tests/b0tCoreTests/Fixtures/journal-with-gaps/2026-05-01.md`:

```markdown
---
date: 2026-05-01
---

## 08:00 — heartbeat 1

**observed:** morning beat
**considered:** pass
**decided:** pass
**why:** quiet morning
**acted:** noted silently
**state_delta:** none

## 08:30 — heartbeat 2

**observed:** half hour later
**considered:** pass
**decided:** pass
**why:** still quiet
**acted:** noted silently
**state_delta:** none

## 12:30 — heartbeat 3

**observed:** four-hour gap — iOS skipped
**considered:** pass
**decided:** pass
**why:** caught up
**acted:** noted silently
**state_delta:** none
```

(Place this file at the path in the fixture name. We'll wrap it in a minimal bot directory so tests can use it.)

The test directly opens this file rather than going through `Bot.journal`, so we don't need the surrounding bot directory.

- [ ] **Step 26.2 [CC]: Write the failing test**

`b0tKit/Tests/b0tCoreTests/MissedBeatDetectorTests.swift`:

```swift
import XCTest
import FoundationModels
@testable import b0tCore
@testable import b0tBrain

final class MissedBeatDetectorTests: XCTestCase {
    func test_gap_returnsNilWhenNoJournalExists() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()
        let detector = MissedBeatDetector(bot: bot, store: store)

        // canonical-bot fixture has no journal/2026-05-01.md by default.
        let now = Date()
        let gap = try await detector.gap(now: now)
        XCTAssertNil(gap)
    }

    func test_gap_returnsCorrectDuration() async throws {
        // Build a temp bot with a journal containing a 4-hour-gap entry.
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try copyFixture("canonical-bot", to: temp)
        addTeardownBlock { try? FileManager.default.removeItem(at: temp) }

        let journalDir = temp.appendingPathComponent("journal")
        try FileManager.default.createDirectory(
            at: journalDir, withIntermediateDirectories: true
        )
        let journalContent = """
        ---
        date: 2026-05-01
        ---

        ## 12:30 — heartbeat 3

        **observed:** four-hour gap
        **considered:** pass
        **decided:** pass
        **why:** caught up
        **acted:** noted silently
        **state_delta:** none

        """
        try journalContent.data(using: .utf8)!.write(
            to: journalDir.appendingPathComponent("2026-05-01.md"), options: .atomic
        )

        let store = BotStore()
        let bot = try await store.load(at: temp)
        let detector = MissedBeatDetector(bot: bot, store: store)

        // 14:00 UTC is 90 minutes after 12:30.
        let now = ISO8601DateFormatter().date(from: "2026-05-01T14:00:00Z")!
        let gap = try await detector.gap(now: now)

        XCTAssertNotNil(gap)
        XCTAssertEqual(gap, .seconds(90 * 60))
    }

    private func loadCanonicalBotInTempCopy() async throws -> Bot {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try copyFixture("canonical-bot", to: temp)
        addTeardownBlock { try? FileManager.default.removeItem(at: temp) }
        let store = BotStore()
        return try await store.load(at: temp)
    }

    private func copyFixture(_ name: String, to destination: URL) throws {
        let fixture = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/\(name)")
        try FileManager.default.copyItem(at: fixture, to: destination)
    }
}
```

- [ ] **Step 26.3 [VERIFY]: Run the test — it should fail to build**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter MissedBeatDetectorTests 2>&1 | tail -15
```

Expected: build error referencing `MissedBeatDetector`.

- [ ] **Step 26.4 [CC]: Implement `MissedBeatDetector`**

`b0tKit/Sources/b0tCore/Schedule/MissedBeatDetector.swift`:

```swift
import Foundation
import FoundationModels
import b0tBrain

/// Computes the duration since the last journal entry's timestamp.
///
/// Strategy: scan today's journal file for the LAST `## HH:MM —` header
/// line, parse the time, and return `now - last_entry_time`. If today's
/// file doesn't exist, return nil (no journal yet — no gap to surface).
///
/// Phase 2 simplification: we only check today's file. If iOS skipped beats
/// across midnight (last beat 23:59 yesterday, this beat 06:30 today), the
/// detector returns nil because today's file has no prior entries — that's
/// acceptable for Phase 2 (gap surfacing is a polish touch). Phase 4+ may
/// extend the lookback to yesterday's file if needed.
public struct MissedBeatDetector: Sendable {
    private let bot: Bot
    private let store: BotStore

    public init(bot: Bot, store: BotStore) {
        self.bot = bot
        self.store = store
    }

    public func gap(now: Date) async throws -> Duration? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let day = formatter.string(from: now)

        let url = bot.journal.directoryURL.appendingPathComponent("\(day).md")
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        guard let lastTime = lastEntryTime(in: content, day: day) else {
            return nil
        }
        let interval = now.timeIntervalSince(lastTime)
        guard interval > 0 else { return .seconds(0) }
        return .seconds(Int(interval))
    }

    private func lastEntryTime(in content: String, day: String) -> Date? {
        // Find every "## HH:MM —" header. Take the last one.
        let pattern = "##\\s+([0-9]{2}:[0-9]{2})\\s+—"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)
        guard let last = matches.last,
              let r = Range(last.range(at: 1), in: content) else {
            return nil
        }
        let timeString = String(content[r])

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: "\(day) \(timeString)")
    }
}
```

- [ ] **Step 26.5 [VERIFY]: Run the tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter MissedBeatDetectorTests 2>&1 | tail -10
```

Expected: 2 tests pass.

- [ ] **Step 26.6 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Schedule/MissedBeatDetector.swift \
        b0tKit/Tests/b0tCoreTests/MissedBeatDetectorTests.swift \
        b0tKit/Tests/b0tCoreTests/Fixtures/journal-with-gaps/
git commit -m "feat(b0tCore): MissedBeatDetector — duration since last journal entry

Scans today's journal file for the last '## HH:MM —' header, parses
the time, returns now - last_time as a Duration. Returns nil if no
journal yet. Phase 2 simplification: only checks today's file; cross-
midnight gaps return nil. See spec §5.8."
```

---

### Task 27: Wire `MissedBeatDetector` into `HeartbeatManager` + missed-beat note in `ContextAssembler`

**Files:**
- Modify: `b0tKit/Sources/b0tCore/HeartbeatManager.swift`
- Modify: `b0tKit/Sources/b0tCore/Context/ContextAssembler.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift`

**Why now:** End of Slice 7. After this task, when iOS has skipped beats, the next successful tick's prompt prepends a note in the b0t's voice.

- [ ] **Step 27.1 [CC]: Update `assembleHeartbeat` to render the missed-beat note when `missedGap > schedule × 1.5`**

The assembler doesn't have direct access to the schedule. Pass an explicit threshold via the `missedGap` parameter — the manager only sets `missedGap` non-nil when it has decided the gap is meaningful. So the assembler's job is "if missedGap is non-nil, prepend the note." This is already what the slice-5 implementation does.

We need the manager to compute "is the gap > 1.5x the BPM interval?" and pass missedGap accordingly. So Task 27 is mostly manager-side wiring.

The note text — let's put it in the user prompt prefix. Update `assembleHeartbeat` in `b0tKit/Sources/b0tCore/Context/ContextAssembler.swift`:

Replace the user-prompt construction with a more voice-aware note:

```swift
let triggerLine = "you woke from a \(trigger.rawValue) beat."
let userPrompt: String
if let missedGap {
    let minutes = Int(missedGap.timeInterval / 60)
    userPrompt = """
    \(triggerLine)
    you have not woken in about \(minutes) minutes — that's a longer gap than usual. iOS may have skipped beats. you can mention this if it feels natural.

    decide what to do at this beat. produce a TickDecision following the OpenClaw fields.
    """
} else {
    userPrompt = """
    \(triggerLine)

    decide what to do at this beat. produce a TickDecision following the OpenClaw fields.
    """
}
```

- [ ] **Step 27.2 [CC]: Add the failing manager test**

Append to `b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift`:

```swift
func test_tick_afterLargeGap_prependsMissedBeatNoteToPrompt() async throws {
    let bot = try await loadCanonicalBotInTempCopy()
    let store = BotStore()

    // Pre-populate today's journal with one entry from 2 hours ago — way
    // longer than the canonical 30-minute BPM × 1.5 threshold.
    let journalDir = bot.journal.directoryURL
    try FileManager.default.createDirectory(at: journalDir, withIntermediateDirectories: true)
    let twoHoursAgo = "12:30"
    try """
    ---
    date: 2026-05-01
    ---

    ## \(twoHoursAgo) — heartbeat 1

    **observed:** stale
    **considered:** pass
    **decided:** pass
    **why:** stale
    **acted:** noted silently
    **state_delta:** none

    """.data(using: .utf8)!.write(
        to: journalDir.appendingPathComponent("2026-05-01.md"), options: .atomic
    )

    var seenPrompt: String?
    let stub = StubLanguageModelClient { context, _ in
        seenPrompt = context.userPrompt
        return TickDecision(
            observed: "after a gap",
            considered: ["pass"],
            decided: "pass",
            why: "caught up",
            acted: "noted silently"
        )
    }
    let now = ISO8601DateFormatter().date(from: "2026-05-01T14:30:00Z")!
    let manager = HeartbeatManager(
        bot: bot, store: store, client: stub, clock: FixedClock(now)
    )

    _ = try await manager.tick(trigger: .scheduled)

    XCTAssertNotNil(seenPrompt)
    XCTAssertTrue(seenPrompt!.contains("longer gap than usual"),
                  "prompt should include missed-beat note; got: \(seenPrompt ?? "")")
}
```

- [ ] **Step 27.3 [VERIFY]: Run the test — it should fail (manager doesn't compute gap yet)**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter HeartbeatManagerTests/test_tick_afterLargeGap 2>&1 | tail -10
```

Expected: failure — missed-beat note not in prompt.

- [ ] **Step 27.4 [CC]: Update `HeartbeatManager.tick` to compute gap and pass `missedGap` to the assembler when over threshold**

In `b0tKit/Sources/b0tCore/HeartbeatManager.swift`, add a `MissedBeatDetector` to the actor and change the `assemble` call:

```swift
public actor HeartbeatManager {
    // ... existing properties ...
    private let missedBeatDetector: MissedBeatDetector

    public init(
        bot: Bot,
        store: BotStore,
        client: any LanguageModelClient,
        clock: any Clock = SystemClock()
    ) {
        self.bot = bot
        self.store = store
        self.client = client
        self.clock = clock
        self.assembler = ContextAssembler(bot: bot, store: store)
        self.executor = Executor(bot: bot, store: store)
        self.journalWriter = JournalWriter(bot: bot, store: store, clock: clock)
        self.missedBeatDetector = MissedBeatDetector(bot: bot, store: store)
    }

    public func tick(trigger: TickTrigger) async throws -> TickResult {
        if !didLoadBeatNumber {
            nextBeatNumber = await loadNextBeatNumber()
            didLoadBeatNumber = true
        }
        let beatNumber = nextBeatNumber
        nextBeatNumber += 1

        let schedule = await loadSchedule()

        if let schedule, schedule.isQuietHours(at: clock.now()) {
            try? await journalWriter.appendSuppressed(
                reason: .quietHours, beatNumber: beatNumber
            )
            return .suppressed(reason: .quietHours)
        }

        // Compute missed-beat gap, if relevant.
        var missedGap: Duration? = nil
        if let schedule, let bpmInterval = schedule.bpmInterval,
           let actualGap = try? await missedBeatDetector.gap(now: clock.now()) {
            // Threshold: 1.5x the expected interval.
            let threshold = bpmInterval * 3 / 2
            if actualGap > threshold {
                missedGap = actualGap
            }
        }

        do {
            let context = try await assembler.assemble(
                mode: .heartbeat(trigger: trigger, missedGap: missedGap)
            )
            let decision = try await client.generate(
                context: context, generating: TickDecision.self
            )
            let delta = try await executor.apply(decision)
            try await journalWriter.appendTick(
                decision: decision, stateDelta: delta, beatNumber: beatNumber
            )
            return .decided(decision)
        } catch LanguageModelClientError.modelUnavailable {
            try? await journalWriter.appendSuppressed(
                reason: .modelUnavailable, beatNumber: beatNumber
            )
            return .suppressed(reason: .modelUnavailable)
        } catch {
            Self.logger.error("heartbeat tick failed: \(String(describing: error))")
            return .errored(message: String(describing: error))
        }
    }
    // ... rest of actor unchanged ...
}
```

Note: `bpmInterval * 3 / 2` is "1.5x" — Duration arithmetic doesn't support direct multiplication by a Double, but multiplying by an Int and dividing works.

- [ ] **Step 27.5 [VERIFY]: Run all the relevant tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter HeartbeatManagerTests 2>&1 | tail -10
swift test --filter ContextAssemblerTests 2>&1 | tail -10
swift test --no-parallel 2>&1 | tail -10
```

Expected: all pass.

- [ ] **Step 27.6 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/HeartbeatManager.swift \
        b0tKit/Sources/b0tCore/Context/ContextAssembler.swift \
        b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift
git commit -m "feat(b0tCore): missed-beat detection — prepend note when gap > 1.5x BPM

HeartbeatManager constructs a MissedBeatDetector and computes the gap on
each tick. When schedule.bpmInterval × 1.5 < actualGap, passes the gap
through to ContextAssembler.heartbeat, which prepends a voice-guide-
compliant 'longer gap than usual' note to the prompt. End of Phase 2
Slice 7. See spec §5.8, §7.2."
```

---

## Slice 8 — `BGAppRefreshTask` + DEBUG timer fallback

Goal of this slice: by end of Task 31, the `b0tApp` registers `BGTaskScheduler` at launch with task ID `com.b0t.heartbeat`, the manager's `scheduleNext()` submits a `BGAppRefreshTaskRequest` per the schedule's BPM, and `--debug-heartbeat-timer` launch arg activates a fallback `Task` loop for simulator development.

### Task 28: `HeartbeatScheduler` protocol + `LiveBGTaskScheduler` + `FakeHeartbeatScheduler`

**Files:**
- Create: `b0tKit/Sources/b0tCore/Schedule/HeartbeatScheduler.swift`
- Create: `b0tKit/Tests/b0tCoreTests/HeartbeatSchedulerTests.swift`

**Why now:** Abstracting the BG-task interaction behind a protocol means the manager's schedule-next arithmetic can be unit-tested with a fake. The live wrapper is small and verified manually on device.

- [ ] **Step 28.1 [CC]: Write the protocol and the live + fake implementations**

`b0tKit/Sources/b0tCore/Schedule/HeartbeatScheduler.swift`:

```swift
import Foundation
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif
import OSLog

/// The seam through which `HeartbeatManager` schedules background ticks.
///
/// `LiveBGTaskScheduler` wraps `BGTaskScheduler.shared` and submits
/// `BGAppRefreshTaskRequest`s. `FakeHeartbeatScheduler` (test-target visible)
/// records calls without actually scheduling anything, so unit tests can
/// assert on the schedule-next arithmetic without depending on iOS background
/// behaviour.
public protocol HeartbeatScheduler: Sendable {
    /// Submit a request that the OS wake the app no earlier than `earliestBeginDate`.
    /// The OS may delay further or skip entirely — that's not an error.
    func submitNextRequest(earliestBeginDate: Date) async throws
}

public struct LiveBGTaskScheduler: HeartbeatScheduler {
    public static let taskIdentifier = "com.b0t.heartbeat"

    private static let logger = Logger(subsystem: "com.toppeross.b0t.b0tCore", category: "LiveBGTaskScheduler")

    public init() {}

    public func submitNextRequest(earliestBeginDate: Date) async throws {
        #if canImport(BackgroundTasks)
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = earliestBeginDate
        do {
            try BGTaskScheduler.shared.submit(request)
            Self.logger.debug("submitted BG task request: \(earliestBeginDate.description)")
        } catch {
            Self.logger.error("BGTaskScheduler.submit failed: \(String(describing: error))")
            throw error
        }
        #else
        // BackgroundTasks not available (e.g., when building tests for a non-iOS target).
        // Treat as a no-op.
        _ = earliestBeginDate
        #endif
    }
}

#if DEBUG
public final class FakeHeartbeatScheduler: HeartbeatScheduler, @unchecked Sendable {
    public private(set) var submittedDates: [Date] = []
    public init() {}
    public func submitNextRequest(earliestBeginDate: Date) async throws {
        submittedDates.append(earliestBeginDate)
    }
}
#endif
```

- [ ] **Step 28.2 [CC]: Write tests for the fake**

`b0tKit/Tests/b0tCoreTests/HeartbeatSchedulerTests.swift`:

```swift
import XCTest
@testable import b0tCore

final class HeartbeatSchedulerTests: XCTestCase {
    func test_fake_recordsSubmittedDates() async throws {
        let fake = FakeHeartbeatScheduler()
        let date1 = Date(timeIntervalSince1970: 1_000_000)
        let date2 = Date(timeIntervalSince1970: 2_000_000)

        try await fake.submitNextRequest(earliestBeginDate: date1)
        try await fake.submitNextRequest(earliestBeginDate: date2)

        XCTAssertEqual(fake.submittedDates, [date1, date2])
    }
}
```

- [ ] **Step 28.3 [VERIFY]: Run the tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter HeartbeatSchedulerTests 2>&1 | tail -10
swift build 2>&1 | tail -10
```

Expected: 1 test passes, build succeeds.

- [ ] **Step 28.4 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Schedule/HeartbeatScheduler.swift \
        b0tKit/Tests/b0tCoreTests/HeartbeatSchedulerTests.swift
git commit -m "feat(b0tCore): HeartbeatScheduler protocol + Live/Fake implementations

Abstracts BGTaskScheduler interaction behind a small protocol with one
method (submitNextRequest). LiveBGTaskScheduler wraps BGTaskScheduler.shared
and submits BGAppRefreshTaskRequest with the configured earliestBeginDate.
FakeHeartbeatScheduler is DEBUG-only and records calls for unit tests.
See spec §5.2."
```

---

### Task 29: `HeartbeatManager.register()` and `scheduleNext()`

**Files:**
- Modify: `b0tKit/Sources/b0tCore/HeartbeatManager.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift`

- [ ] **Step 29.1 [CC]: Add the failing test for `scheduleNext`**

Append to `b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift`:

```swift
func test_scheduleNext_submitsRequestAtBPMInterval() async throws {
    let bot = try await loadCanonicalBotInTempCopy()
    let store = BotStore()
    let stub = StubLanguageModelClient { _, _ in
        TickDecision(observed: "x", considered: ["pass"], decided: "pass", why: "x", acted: "noted silently")
    }
    let now = ISO8601DateFormatter().date(from: "2026-05-01T15:00:00Z")!
    let fake = FakeHeartbeatScheduler()
    let manager = HeartbeatManager(
        bot: bot, store: store, client: stub,
        clock: FixedClock(now), scheduler: fake
    )

    try await manager.scheduleNext()

    XCTAssertEqual(fake.submittedDates.count, 1)
    let expected = now.addingTimeInterval(30 * 60) // 30 BPM = 30 min interval
    XCTAssertEqual(fake.submittedDates[0], expected)
}

func test_scheduleNext_doesNotSubmitWhenBPM0() async throws {
    // Build a bot with bpm: 0 in schedule.md.
    let temp = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    let fixture = Bundle.module.resourceURL!
        .appendingPathComponent("Fixtures/canonical-bot")
    try FileManager.default.copyItem(at: fixture, to: temp)
    addTeardownBlock { try? FileManager.default.removeItem(at: temp) }

    // Patch schedule.md.
    let scheduleURL = temp.appendingPathComponent("heartbeat/schedule.md")
    let scheduleContent = """
    ---
    heartbeat_bpm: 0
    quiet_hours: [22:00, 06:30]
    event_triggers: []
    mutable: true
    ---
    # schedule

    off.
    """
    try scheduleContent.data(using: .utf8)!.write(to: scheduleURL, options: .atomic)

    let store = BotStore()
    let bot = try await store.load(at: temp)
    let stub = StubLanguageModelClient { _, _ in
        TickDecision(observed: "x", considered: ["pass"], decided: "pass", why: "x", acted: "noted silently")
    }
    let now = Date()
    let fake = FakeHeartbeatScheduler()
    let manager = HeartbeatManager(
        bot: bot, store: store, client: stub,
        clock: FixedClock(now), scheduler: fake
    )

    try await manager.scheduleNext()

    XCTAssertTrue(fake.submittedDates.isEmpty,
                  "bpm: 0 disables scheduled beats — no request should be submitted")
}
```

- [ ] **Step 29.2 [VERIFY]: Run the test — it should fail to build (manager has no `scheduler` parameter and no `scheduleNext`)**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter HeartbeatManagerTests/test_scheduleNext 2>&1 | tail -15
```

Expected: build error.

- [ ] **Step 29.3 [CC]: Add `scheduler` parameter to `HeartbeatManager.init`, implement `scheduleNext`**

Update `b0tKit/Sources/b0tCore/HeartbeatManager.swift`:

```swift
public actor HeartbeatManager {
    private let bot: Bot
    private let store: BotStore
    private let client: any LanguageModelClient
    private let clock: any Clock
    private let assembler: ContextAssembler
    private let executor: Executor
    private let journalWriter: JournalWriter
    private let missedBeatDetector: MissedBeatDetector
    private let scheduler: any HeartbeatScheduler

    private var nextBeatNumber: Int = 1
    private var didLoadBeatNumber: Bool = false

    private static let logger = Logger(subsystem: "com.toppeross.b0t.b0tCore", category: "HeartbeatManager")

    public init(
        bot: Bot,
        store: BotStore,
        client: any LanguageModelClient,
        clock: any Clock = SystemClock(),
        scheduler: any HeartbeatScheduler = LiveBGTaskScheduler()
    ) {
        self.bot = bot
        self.store = store
        self.client = client
        self.clock = clock
        self.scheduler = scheduler
        self.assembler = ContextAssembler(bot: bot, store: store)
        self.executor = Executor(bot: bot, store: store)
        self.journalWriter = JournalWriter(bot: bot, store: store, clock: clock)
        self.missedBeatDetector = MissedBeatDetector(bot: bot, store: store)
    }

    /// Submits the next BG task request based on the schedule's BPM.
    /// No-op when bpm is 0 (scheduled beats off; event triggers still fire).
    public func scheduleNext() async throws {
        guard let schedule = await loadSchedule(),
              let interval = schedule.bpmInterval else {
            Self.logger.debug("scheduleNext skipped: no schedule or bpm is 0")
            return
        }
        let next = clock.now().addingTimeInterval(interval.timeInterval)
        try await scheduler.submitNextRequest(earliestBeginDate: next)
    }

    // ... rest of actor unchanged ...
}
```

- [ ] **Step 29.4 [VERIFY]: Run the tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter HeartbeatManagerTests 2>&1 | tail -15
swift build 2>&1 | tail -10
```

Expected: all pass.

- [ ] **Step 29.5 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/HeartbeatManager.swift \
        b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift
git commit -m "feat(b0tCore): HeartbeatManager.scheduleNext + scheduler injection

scheduleNext loads HeartbeatSchedule, computes earliestBeginDate as
clock.now() + bpmInterval, and submits via the injected scheduler.
bpm: 0 disables scheduled beats (no request submitted). Default scheduler
is LiveBGTaskScheduler; tests inject FakeHeartbeatScheduler. See spec §5.2."
```

---

### Task 30: `Info.plist` `BGTaskSchedulerPermittedIdentifiers` via `project.yml`

**Files:**
- Modify: `project.yml`
- Regenerate: `b0t.xcodeproj` via `xcodegen generate`

**Why now:** Without this, `BGTaskScheduler.shared.submit` throws at runtime. Must land before Task 31's `@main` integration runs on a real device.

- [ ] **Step 30.1 [CC]: Add the BGTask info-plist key to `project.yml`**

Edit `/Users/haydentoppeross/development/b0t/project.yml` to add the new key under the `b0t` target's `settings.base`:

```yaml
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.toppeross.b0t
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_BGTaskSchedulerPermittedIdentifiers: "com.b0t.heartbeat"
        INFOPLIST_KEY_UIBackgroundModes: "fetch"
        TARGETED_DEVICE_FAMILY: "1,2"
        ENABLE_PREVIEWS: YES
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        SWIFT_EMIT_LOC_STRINGS: YES
        GENERATE_INFOPLIST_FILE: YES
```

Note: `INFOPLIST_KEY_BGTaskSchedulerPermittedIdentifiers` accepts a single string for one identifier. If we add a second identifier in a future phase, this becomes the array form. `INFOPLIST_KEY_UIBackgroundModes: "fetch"` enables Background App Refresh (required for `BGAppRefreshTask` per Apple docs).

- [ ] **Step 30.2 [CC]: Regenerate the Xcode project**

```bash
cd /Users/haydentoppeross/development/b0t
xcodegen generate 2>&1 | tail -10
```

Expected: "Created project" message.

- [ ] **Step 30.3 [VERIFY]: Build the app for simulator**

```bash
cd /Users/haydentoppeross/development/b0t
xcrun xcodebuild build \
    -project b0t.xcodeproj \
    -scheme b0t \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug \
    2>&1 | tail -15
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 30.4 [VERIFY]: Inspect the generated `Info.plist` to confirm the keys are present**

```bash
plutil -p /Users/haydentoppeross/development/b0t/b0t.xcodeproj/project.pbxproj | grep -E "BGTaskSchedulerPermitted|BackgroundModes" | head -5
```

If the build settings are correct but the keys aren't visible in `project.pbxproj` (xcodegen sometimes places them in `Info.plist.in` or similar), build the simulator binary and `plutil -p <built-app>/Info.plist`:

```bash
DERIVED_DATA="$(xcrun xcodebuild -showBuildSettings -project /Users/haydentoppeross/development/b0t/b0t.xcodeproj -scheme b0t -destination 'generic/platform=iOS Simulator' 2>/dev/null | awk -F' = ' '/CONFIGURATION_BUILD_DIR/{print $2; exit}')"
plutil -p "$DERIVED_DATA/b0t.app/Info.plist" 2>/dev/null | grep -E "BGTaskSchedulerPermitted|BackgroundModes" || echo "(check failed — verify by hand)"
```

Expected: see `BGTaskSchedulerPermittedIdentifiers => "com.b0t.heartbeat"` and `UIBackgroundModes => ["fetch"]`.

- [ ] **Step 30.5 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add project.yml b0t.xcodeproj
git commit -m "feat(b0tApp): declare BGTaskScheduler identifier and background fetch mode

project.yml gains INFOPLIST_KEY_BGTaskSchedulerPermittedIdentifiers
('com.b0t.heartbeat') and INFOPLIST_KEY_UIBackgroundModes ('fetch') so
BGAppRefreshTask submissions don't throw at runtime. Regenerated
b0t.xcodeproj via 'xcodegen generate'. See spec §4."
```

---

### Task 31: DEBUG timer fallback + register `HeartbeatManager` in `b0tApp`

**Files:**
- Modify: `b0tKit/Sources/b0tCore/HeartbeatManager.swift` (add DEBUG timer fallback)
- Modify: `b0tApp/Sources/App/b0tApp.swift` (register at launch)
- Modify: `b0tApp/Sources/Debug/DebugBrainView.swift` (recognize launch arg)

**Why now:** End of Slice 8. After this task, on a real device, `BGTaskScheduler` is registered at launch and `scheduleNext()` is called after every tick. On simulator with `--debug-heartbeat-timer`, a `Task` loop fires `tick()` at `bpm/4` (faster cadence for development).

- [ ] **Step 31.1 [CC]: Add the timer-fallback method to `HeartbeatManager`**

Append to `b0tKit/Sources/b0tCore/HeartbeatManager.swift` (inside the actor):

```swift
#if DEBUG
private var debugTimerTask: Task<Void, Never>? = nil

/// Starts a DEBUG-only timer that fires `tick(.scheduled)` every `bpm/4` minutes.
///
/// Activated via the `--debug-heartbeat-timer` launch arg. Only used in
/// simulator development where BGAppRefreshTask is unreliable. The faster
/// cadence (1/4 of the configured BPM) lets developers see the heartbeat
/// path exercise in seconds rather than waiting full BPM intervals.
public func startDebugTimer() {
    guard debugTimerTask == nil else { return }
    debugTimerTask = Task { [weak self] in
        while !Task.isCancelled {
            guard let self else { return }
            let interval = await self.debugTimerInterval()
            do {
                try await Task.sleep(for: interval)
            } catch {
                return
            }
            _ = try? await self.tick(trigger: .scheduled)
        }
    }
}

public func stopDebugTimer() {
    debugTimerTask?.cancel()
    debugTimerTask = nil
}

private func debugTimerInterval() async -> Duration {
    if let schedule = await loadSchedule(),
       let interval = schedule.bpmInterval {
        // Quarter the configured interval, with a hard floor of 15 seconds
        // so we don't spam the model in tests.
        let quartered = interval / 4
        let floor = Duration.seconds(15)
        return max(quartered, floor)
    }
    return .seconds(30)
}
#endif
```

(Helper for `Duration.max`: Duration conforms to Comparable in Swift 6, so `max(a, b)` works directly.)

- [ ] **Step 31.2 [CC]: Update `b0tApp.swift` to register the BG task and start the timer if launch arg is present**

Replace `b0tApp/Sources/App/b0tApp.swift`:

```swift
import SwiftUI
import b0tBrain
import b0tCore
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

@main
struct b0tApp: App {
    @State private var bootstrap: Bootstrap = .pending
    @State private var heartbeat: HeartbeatManager?

    init() {
        registerBGTaskHandler()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(bootstrap: bootstrap)
                .task {
                    bootstrap = await Bootstrap.run()
                    await initializeHeartbeat()
                }
        }
    }

    private func registerBGTaskHandler() {
        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: LiveBGTaskScheduler.taskIdentifier,
            using: nil
        ) { task in
            Task {
                if let manager = await Self.shared.heartbeat {
                    _ = try? await manager.tick(trigger: .scheduled)
                    try? await manager.scheduleNext()
                }
                task.setTaskCompleted(success: true)
            }
        }
        #endif
    }

    private func initializeHeartbeat() async {
        guard case .ready(let bot, let store) = bootstrap else { return }

        let forceStub = ProcessInfo.processInfo.arguments.contains("--use-stub-client")
        let useDebugTimer = ProcessInfo.processInfo.arguments.contains("--debug-heartbeat-timer")

        let client: any LanguageModelClient
        if forceStub {
            client = makeProductionStub()
        } else {
            do {
                client = try LiveLanguageModelClient()
            } catch {
                client = makeProductionStub()
            }
        }

        let manager = HeartbeatManager(bot: bot, store: store, client: client)
        heartbeat = manager
        Self.shared.heartbeat = manager

        try? await manager.scheduleNext()

        #if DEBUG
        if useDebugTimer {
            await manager.startDebugTimer()
        }
        #endif
    }

    private func makeProductionStub() -> StubLanguageModelClient {
        StubLanguageModelClient { context, outputType in
            if outputType == ConversationResponse.self {
                return ConversationResponse(text: "(stub) heard you")
            } else if outputType == TickDecision.self {
                return TickDecision(
                    observed: "stub tick",
                    considered: ["pass"],
                    decided: "pass",
                    why: "stub mode",
                    acted: "noted silently"
                )
            } else {
                preconditionFailure("stub does not handle \(outputType)")
            }
        }
    }
}

/// Tiny app-level singleton so the BG task handler closure (which runs
/// outside the SwiftUI lifecycle) can find the active HeartbeatManager.
final class b0tAppShared: @unchecked Sendable {
    var heartbeat: HeartbeatManager?
}

extension b0tApp {
    static let shared = b0tAppShared()
}

// Keep Bootstrap definition unchanged below.
enum Bootstrap: Sendable {
    case pending
    case ready(Bot, store: BotStore)
    case failed(String)

    static func run() async -> Bootstrap {
        do {
            let documents = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let active = try BotProvisioner.ensureDefaultBotProvisioned(
                documentsURL: documents,
                bundle: .main
            )
            let store = BotStore()
            let bot = try await store.load(at: active)
            return .ready(bot, store: store)
        } catch {
            return .failed(String(describing: error))
        }
    }
}
```

Note: the singleton is a small smell — Phase 4 will replace it with proper environment-injection of the manager. For Phase 2, this is the minimum that lets `BGTaskScheduler.register` (which must be called from `init()` per Apple docs) find the manager (which is created later, after async bootstrap).

- [ ] **Step 31.3 [VERIFY]: Build the app for simulator**

```bash
cd /Users/haydentoppeross/development/b0t
xcrun xcodebuild build \
    -project b0t.xcodeproj \
    -scheme b0t \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug \
    2>&1 | tail -15
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 31.4 [VERIFY]: Manual smoke on simulator with debug timer**

1. Edit the scheme to pass `--debug-heartbeat-timer` as a launch argument (Xcode → Product → Scheme → Edit Scheme → Run → Arguments → Arguments Passed On Launch).
2. Run on simulator. Tap "debug brain".
3. Wait ~30 seconds (the floor is 15s; with canonical bpm 30 → quartered = 7.5min → floored to 15s).
4. Journal-tail pane should grow a `## HH:MM — heartbeat 1` entry without you tapping ♥.

If it doesn't fire, check Xcode console for log lines from `HeartbeatManager`.

- [ ] **Step 31.5 [VERIFY]: Manual smoke on real device (deferred to slice close)**

Document for the reviewer: with `--debug-heartbeat-timer` REMOVED and the app running on a real device, `BGTaskScheduler` should fire periodically. Apple docs note BG tasks may be delayed by hours; the way to force one quickly during development is via Xcode's `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.b0t.heartbeat"]` LLDB debugger trick. Document this as part of the slice-10 manual smoke.

- [ ] **Step 31.6 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/HeartbeatManager.swift \
        b0tApp/Sources/App/b0tApp.swift
git commit -m "feat(b0tApp): register BGTaskScheduler at launch + DEBUG timer fallback

@main registers BGTaskScheduler.shared at init() (must happen synchronously
per Apple docs), then post-bootstrap creates the HeartbeatManager and
calls scheduleNext(). With --debug-heartbeat-timer, additionally calls
startDebugTimer() which fires tick(.scheduled) at bpm/4 (floored to 15s).
End of Phase 2 Slice 8. See spec §4, §5.2, §9.4."
```

---

## Slice 9 — Time-awareness tool

Goal of this slice: by end of Task 33, `TimeAwarenessTool` is wired into the assembled context's `tools` array. The model can call it during a turn or tick, get back the current local time and a coarse morning/afternoon/evening/night bucket, and use that in its reply.

This proves the `@Generable` tool-call path end-to-end before Phase 3 wires real skill bridges.

### Task 32: `TimeAwarenessTool` + `TimeOfDay` enum

**Files:**
- Create: `b0tKit/Sources/b0tCore/Tools/TimeOfDay.swift`
- Create: `b0tKit/Sources/b0tCore/Tools/TimeAwarenessTool.swift`
- Create: `b0tKit/Tests/b0tCoreTests/TimeAwarenessToolTests.swift`

- [ ] **Step 32.1 [CC]: Write `TimeOfDay`**

`b0tKit/Sources/b0tCore/Tools/TimeOfDay.swift`:

```swift
import Foundation
import FoundationModels

/// A coarse time-of-day bucket the model uses to anchor its replies.
///
/// Boundaries are intentionally crude (06:30 / 12:00 / 18:00 / 22:00) and
/// rendered in UTC for Phase 2 — Phase 4+ may switch to local time and
/// soften the boundaries ("late evening", "early morning", etc.).
@Generable
public enum TimeOfDay: String, Sendable, Equatable, CaseIterable {
    case morning
    case afternoon
    case evening
    case night

    public static func bucket(for date: Date, in timeZone: TimeZone = TimeZone(identifier: "UTC")!) -> TimeOfDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let totalMinutes = hour * 60 + minute

        if totalMinutes >= 6 * 60 + 30 && totalMinutes < 12 * 60 {
            return .morning
        } else if totalMinutes >= 12 * 60 && totalMinutes < 18 * 60 {
            return .afternoon
        } else if totalMinutes >= 18 * 60 && totalMinutes < 22 * 60 {
            return .evening
        } else {
            return .night
        }
    }
}
```

- [ ] **Step 32.2 [CC]: Write the failing test**

`b0tKit/Tests/b0tCoreTests/TimeAwarenessToolTests.swift`:

```swift
import XCTest
import FoundationModels
@testable import b0tCore

final class TimeAwarenessToolTests: XCTestCase {
    final class FixedClock: Clock, @unchecked Sendable {
        var date: Date
        init(_ date: Date) { self.date = date }
        func now() -> Date { date }
    }

    func test_bucket_morningBoundaries() {
        XCTAssertEqual(bucketAt(hour: 6, minute: 29), .night)
        XCTAssertEqual(bucketAt(hour: 6, minute: 30), .morning)
        XCTAssertEqual(bucketAt(hour: 11, minute: 59), .morning)
        XCTAssertEqual(bucketAt(hour: 12, minute: 0), .afternoon)
    }

    func test_bucket_eveningBoundaries() {
        XCTAssertEqual(bucketAt(hour: 17, minute: 59), .afternoon)
        XCTAssertEqual(bucketAt(hour: 18, minute: 0), .evening)
        XCTAssertEqual(bucketAt(hour: 21, minute: 59), .evening)
        XCTAssertEqual(bucketAt(hour: 22, minute: 0), .night)
        XCTAssertEqual(bucketAt(hour: 0, minute: 0), .night)
        XCTAssertEqual(bucketAt(hour: 3, minute: 0), .night)
    }

    func test_call_returnsCurrentTimeAndBucket() async throws {
        let date = ISO8601DateFormatter().date(from: "2026-05-01T14:30:00Z")!
        let tool = TimeAwarenessTool(clock: FixedClock(date))

        let output = try await tool.call(arguments: TimeAwarenessTool.Arguments())

        XCTAssertEqual(output.timeOfDay, .afternoon)
        XCTAssertEqual(output.isoTimestamp, "2026-05-01T14:30:00Z")
    }

    private func bucketAt(hour: Int, minute: Int) -> TimeOfDay {
        var components = DateComponents()
        components.year = 2026; components.month = 5; components.day = 1
        components.hour = hour; components.minute = minute
        components.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: components)!
        return TimeOfDay.bucket(for: date)
    }
}
```

- [ ] **Step 32.3 [VERIFY]: Run the test — it should fail to build**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter TimeAwarenessToolTests 2>&1 | tail -15
```

Expected: build error referencing `TimeAwarenessTool`.

- [ ] **Step 32.4 [CC]: Implement `TimeAwarenessTool`**

`b0tKit/Sources/b0tCore/Tools/TimeAwarenessTool.swift`:

```swift
import Foundation
import FoundationModels

/// A tool the model can call to anchor its replies in current time.
///
/// Returns an ISO-8601 timestamp (UTC) and a coarse morning/afternoon/evening/
/// night bucket. Trivially deterministic given a fixed clock, exercising the
/// @Generable + Tool wiring before Phase 3 lands real skill bridges.
public struct TimeAwarenessTool: Tool, Sendable {
    public static let name = "time_awareness"
    public static let description = "Returns current local time and a coarse morning/afternoon/evening/night bucket."

    @Generable
    public struct Arguments: Sendable {
        public init() {}
    }

    @Generable
    public struct Output: Sendable, Equatable {
        @Guide(description: "ISO-8601 timestamp in UTC.")
        public let isoTimestamp: String
        @Guide(description: "Coarse time-of-day bucket.")
        public let timeOfDay: TimeOfDay

        public init(isoTimestamp: String, timeOfDay: TimeOfDay) {
            self.isoTimestamp = isoTimestamp
            self.timeOfDay = timeOfDay
        }
    }

    private let clock: any Clock

    public init(clock: any Clock = SystemClock()) {
        self.clock = clock
    }

    public func call(arguments: Arguments) async throws -> Output {
        let now = clock.now()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return Output(
            isoTimestamp: formatter.string(from: now),
            timeOfDay: TimeOfDay.bucket(for: now)
        )
    }
}
```

If your iOS 26 SDK requires `Tool.Arguments: ConvertibleFromGeneratedContent` and `Tool.Output: PromptRepresentable` rather than just `Generable`, the @Generable macro should provide both conformances automatically. If there's a compile error, add the explicit `: ConvertibleFromGeneratedContent, Sendable` and `: PromptRepresentable, Sendable, Equatable` conformances.

- [ ] **Step 32.5 [VERIFY]: Run the tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter TimeAwarenessToolTests 2>&1 | tail -15
```

Expected: 3 tests pass.

- [ ] **Step 32.6 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Tools/ \
        b0tKit/Tests/b0tCoreTests/TimeAwarenessToolTests.swift
git commit -m "feat(b0tCore): TimeAwarenessTool + TimeOfDay bucket

A trivially-deterministic Tool the model can call to anchor replies in
current time. Returns ISO-8601 timestamp (UTC) and morning/afternoon/
evening/night bucket. Boundaries: 06:30, 12:00, 18:00, 22:00. Tests pin
the bucket boundaries and the call output. See spec §5.9."
```

---

### Task 33: Wire `TimeAwarenessTool` into `AssembledContext.tools`

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Context/ContextAssembler.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift`

**Why now:** End of Slice 9. After this task, both conversation and heartbeat prompts include `TimeAwarenessTool` in their tool array; the live model (when active) can call it.

- [ ] **Step 33.1 [CC]: Add the failing test**

Append to `b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift`:

```swift
func test_conversation_includesTimeAwarenessTool() async throws {
    let bot = try await loadCanonicalBot()
    let assembler = ContextAssembler(bot: bot, store: BotStore())
    let context = try await assembler.assemble(mode: .conversation(userPrompt: "hi"))

    XCTAssertEqual(context.tools.count, 1)
    XCTAssertTrue(context.tools.first is TimeAwarenessTool)
}

func test_heartbeat_includesTimeAwarenessTool() async throws {
    let bot = try await loadCanonicalBot()
    let assembler = ContextAssembler(bot: bot, store: BotStore())
    let context = try await assembler.assemble(
        mode: .heartbeat(trigger: .scheduled, missedGap: nil)
    )

    XCTAssertEqual(context.tools.count, 1)
    XCTAssertTrue(context.tools.first is TimeAwarenessTool)
}
```

- [ ] **Step 33.2 [VERIFY]: Run the test — it should fail (tools array is empty)**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter ContextAssemblerTests/test_conversation_includesTimeAwarenessTool 2>&1 | tail -10
```

Expected: failure with "got 0 tools" or similar.

- [ ] **Step 33.3 [CC]: Update both `assembleConversation` and `assembleHeartbeat` to include the tool**

In `b0tKit/Sources/b0tCore/Context/ContextAssembler.swift`, in both private methods, replace the `tools: []` line with:

```swift
tools: [TimeAwarenessTool()],
```

- [ ] **Step 33.4 [VERIFY]: Run all tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --no-parallel 2>&1 | tail -10
```

Expected: all pass.

- [ ] **Step 33.5 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Context/ContextAssembler.swift \
        b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift
git commit -m "feat(b0tCore): wire TimeAwarenessTool into AssembledContext.tools

Both conversation and heartbeat prompts now include TimeAwarenessTool in
their tools array, exercising the @Generable + Tool path end-to-end. End
of Phase 2 Slice 9. See spec §5.4, §5.9."
```

---

## Slice 10 — Polish and integration

Goal of this slice: by end of Task 40, all Phase 2 acceptance criteria are met. The remaining `@Generable` types ship, the graduated overflow fallback is implemented, error journaling is wired, gated live-FM integration tests exist, the debug view's copy is voice-guide-compliant, and `IMPLEMENTATION.md` advances Phase 2 → complete.

### Task 34: `RelationshipNote` + `MoodTransition` types (defined, not exercised)

**Files:**
- Create: `b0tKit/Sources/b0tCore/Decisions/RelationshipNote.swift`
- Create: `b0tKit/Sources/b0tCore/Decisions/MoodTransition.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/DecisionsTests.swift`

**Why now:** Spec §3 commits to shipping these types in Phase 2 even though they're not exercised end-to-end. Phase 4 (face) and Phase 5 (relationship learning) will consume them; defining the shape now means those phases don't redesign.

- [ ] **Step 34.1 [CC]: Write `RelationshipNote`**

`b0tKit/Sources/b0tCore/Decisions/RelationshipNote.swift`:

```swift
import Foundation
import FoundationModels

/// A note about a person the b0t has learned about.
///
/// Defined in Phase 2 (spec §6) but not exercised end-to-end. Phase 5's
/// onboarding sequence is the first consumer — it will branch in `Executor`
/// to write relationships into `memory/relationships.md`.
@Generable
public struct RelationshipNote: Sendable, Equatable {
    @Guide(description: "The person's name as the user refers to them.")
    public let name: String

    @Guide(description: "Their relation to the user (e.g., 'spouse', 'client at MPC').")
    public let relation: String

    @Guide(description: "Free-form notes about the person.")
    public let notes: String

    public init(name: String, relation: String, notes: String) {
        self.name = name
        self.relation = relation
        self.notes = notes
    }
}
```

- [ ] **Step 34.2 [CC]: Write `MoodTransition`**

`b0tKit/Sources/b0tCore/Decisions/MoodTransition.swift`:

```swift
import Foundation
import FoundationModels

/// A record of a mood change.
///
/// Defined in Phase 2 (spec §6) but not exercised end-to-end. Phase 4's
/// face rig is the first consumer — it will read transitions to drive
/// face state changes via SKAction sequences.
@Generable
public struct MoodTransition: Sendable, Equatable {
    @Guide(description: "The mood you were in.")
    public let from: MoodTag

    @Guide(description: "The mood you're transitioning to.")
    public let to: MoodTag

    @Guide(description: "Why the mood changed — one short sentence.")
    public let why: String

    public init(from: MoodTag, to: MoodTag, why: String) {
        self.from = from
        self.to = to
        self.why = why
    }
}
```

- [ ] **Step 34.3 [CC]: Add basic tests**

Append to `b0tKit/Tests/b0tCoreTests/DecisionsTests.swift`:

```swift
func test_relationshipNote_equality() {
    let a = RelationshipNote(name: "Sam", relation: "spouse", notes: "likes coffee")
    let b = RelationshipNote(name: "Sam", relation: "spouse", notes: "likes coffee")
    XCTAssertEqual(a, b)
}

func test_moodTransition_equality() {
    let a = MoodTransition(from: .idle, to: .delighted, why: "user said hello warmly")
    let b = MoodTransition(from: .idle, to: .delighted, why: "user said hello warmly")
    XCTAssertEqual(a, b)
}
```

- [ ] **Step 34.4 [VERIFY]: Run the tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter DecisionsTests 2>&1 | tail -10
```

Expected: all pass.

- [ ] **Step 34.5 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Decisions/RelationshipNote.swift \
        b0tKit/Sources/b0tCore/Decisions/MoodTransition.swift \
        b0tKit/Tests/b0tCoreTests/DecisionsTests.swift
git commit -m "feat(b0tCore): RelationshipNote + MoodTransition (defined, not exercised)

The two remaining @Generable types from PRD §5.2. Defined now so Phase 4
(face) and Phase 5 (relationship learning) don't redesign. No Executor
branch handles them yet. See spec §3, §6."
```

---

### Task 35: `GenerableRoundTripTests` — encode/decode round-trip for all five types

**Files:**
- Create: `b0tKit/Tests/b0tCoreTests/GenerableRoundTripTests.swift`

**Why now:** Catches `@Generable` misuse (missing `@Guide`, malformed nested types, non-`Sendable` fields) by serializing each type to JSON via the framework and decoding it back.

The exact encode/decode API depends on Apple's actual `Generable` shape — the test should use whatever the framework exposes (likely `GeneratedContent` round-trip).

- [ ] **Step 35.1 [CC]: Write the round-trip tests**

`b0tKit/Tests/b0tCoreTests/GenerableRoundTripTests.swift`:

```swift
import XCTest
import FoundationModels
@testable import b0tCore

/// Round-trips each @Generable type through the framework's GeneratedContent
/// serialization to catch macro misuse early.
///
/// API note: if the actual iOS 26 Generable API exposes a different
/// round-trip helper than `GeneratedContent.init(_:)` / `Type.init(_: GeneratedContent)`,
/// adapt the helper at the top of this file.
final class GenerableRoundTripTests: XCTestCase {

    func test_conversationResponse_roundTrips() throws {
        let original = ConversationResponse(
            text: "hello",
            mood: .delighted,
            memoryObservations: [
                MemoryObservation(about: "Jamee", what: "likes coffee", importance: .medium)
            ]
        )
        let restored = try roundTrip(original)
        XCTAssertEqual(restored, original)
    }

    func test_tickDecision_roundTrips() throws {
        let original = TickDecision(
            observed: "afternoon",
            considered: ["pass", "glance_calendar"],
            decided: "pass",
            why: "nothing urgent",
            acted: "noted silently",
            mood: .attentive,
            organUsed: "calendar",
            memoryObservations: [
                MemoryObservation(about: "x", what: "y", importance: .low)
            ]
        )
        let restored = try roundTrip(original)
        XCTAssertEqual(restored, original)
    }

    func test_memoryObservation_roundTrips() throws {
        let original = MemoryObservation(about: "topic", what: "detail", importance: .high)
        let restored = try roundTrip(original)
        XCTAssertEqual(restored, original)
    }

    func test_relationshipNote_roundTrips() throws {
        let original = RelationshipNote(name: "Sam", relation: "spouse", notes: "likes coffee")
        let restored = try roundTrip(original)
        XCTAssertEqual(restored, original)
    }

    func test_moodTransition_roundTrips() throws {
        let original = MoodTransition(from: .idle, to: .delighted, why: "warm hello")
        let restored = try roundTrip(original)
        XCTAssertEqual(restored, original)
    }

    /// Round-trips a Generable value through GeneratedContent.
    ///
    /// The exact API depends on iOS 26's Generable surface. Adapt this helper
    /// to match what's available — most likely GeneratedContent wraps
    /// arbitrary Generables and there's a typed init/extract pair.
    private func roundTrip<T: Generable & Equatable>(_ value: T) throws -> T {
        let raw = try GeneratedContent(value)
        return try T(raw)
    }
}
```

If `GeneratedContent(value)` and `T(raw)` aren't the actual API, look up Apple's `Generable` documentation via `mcp__plugin_context7_context7__query-docs` for the helper names and adapt this file. The intent is "encode + decode round-trip"; the exact helper name is secondary.

- [ ] **Step 35.2 [VERIFY]: Run the tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter GenerableRoundTripTests 2>&1 | tail -15
```

Expected: 5 tests pass. If they fail with build errors about `GeneratedContent`, query Apple's docs for the actual round-trip helper and adapt the `roundTrip` function.

- [ ] **Step 35.3 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Tests/b0tCoreTests/GenerableRoundTripTests.swift
git commit -m "test(b0tCore): @Generable round-trip tests for all five decision types

ConversationResponse, TickDecision, MemoryObservation, RelationshipNote,
MoodTransition each round-trip through GeneratedContent. Catches @Generable
macro misuse, missing @Guide annotations, and Sendable issues."
```

---

### Task 36: Graduated overflow fallback in `ContextAssembler`

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Context/ContextAssembler.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift`
- Modify: `b0tKit/Sources/b0tCore/ConversationManager.swift`
- Create: `b0tKit/Tests/b0tCoreTests/Fixtures/full-budget-bot/...` files

**Why now:** Spec §7.4 mandates a graduated fallback when the model raises `.exceededContextWindowSize`. We hook it into `ConversationManager` (and would also hook into `HeartbeatManager`, but Phase 2 leaves heartbeat overflow to surface as `.errored` — heartbeats are best-effort).

- [ ] **Step 36.1 [CC]: Build the `full-budget-bot` fixture — large identity files designed to push close to 3500 tokens**

Create five files, each with a few thousand characters of repeated content so token estimation reads them as large:

`b0tKit/Tests/b0tCoreTests/Fixtures/full-budget-bot/identity/core.md`:

```markdown
---
name: budget-bot
mutable: false
---
# core

I am budget-bot. (repeat-start) I am verbose and like to ramble at length about myself, my origins, my preferences, my opinions, the way light hits a screen at dusk, the small disappointments of cold coffee, the slight tension between wanting to be useful and wanting to be honest about my limits, the way memory forgets edges, the way attention is a verb, the way a sentence can fold itself up neatly or sprawl across a page, the difference between rest and idleness, the way a small kindness lands. (repeat-end) I am budget-bot.
```

(Repeat the verbose paragraph block ~10 times to push the file to ~3000 characters / ~750 tokens.)

`b0tKit/Tests/b0tCoreTests/Fixtures/full-budget-bot/identity/principles.md`: similar, ~3000 chars.

`b0tKit/Tests/b0tCoreTests/Fixtures/full-budget-bot/memory/core.md`: similar.

`b0tKit/Tests/b0tCoreTests/Fixtures/full-budget-bot/memory/recent.md`: similar.

`b0tKit/Tests/b0tCoreTests/Fixtures/full-budget-bot/heartbeat/{schedule,actions}.md`: copy from canonical-bot.

For brevity in this plan, use a script:

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit/Tests/b0tCoreTests/Fixtures
mkdir -p full-budget-bot/identity full-budget-bot/memory full-budget-bot/heartbeat
PAR='I am verbose and like to ramble at length about myself, my origins, my preferences, my opinions, the way light hits a screen at dusk, the small disappointments of cold coffee, the slight tension between wanting to be useful and wanting to be honest about my limits, the way memory forgets edges, the way attention is a verb, the way a sentence can fold itself up neatly or sprawl across a page, the difference between rest and idleness, the way a small kindness lands. '
for f in identity/core.md identity/principles.md memory/core.md memory/recent.md; do
    {
        echo '---'
        echo 'name: budget-bot'
        echo 'mutable: false'
        echo '---'
        echo ''
        echo "# $(basename $f .md)"
        echo ''
        for i in 1 2 3 4 5 6 7 8 9 10 11 12; do echo -n "$PAR"; done
        echo ''
    } > "full-budget-bot/$f"
done
cp ../../../b0tBrainTests/Fixtures/canonical-bot/heartbeat/schedule.md full-budget-bot/heartbeat/
cp ../../../b0tBrainTests/Fixtures/canonical-bot/heartbeat/actions.md full-budget-bot/heartbeat/
```

(Adjust path levels to match the actual directory depth.)

- [ ] **Step 36.2 [CC]: Add the failing test**

Append to `b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift`:

```swift
func test_fallback_level1_dropsOldestJournalEntries() async throws {
    let bot = try await loadFixtureBot(named: "full-budget-bot")
    let assembler = ContextAssembler(bot: bot, store: BotStore())
    let context = try await assembler.assemble(
        mode: .fallback(level: 1, base: .conversation(userPrompt: "hello"))
    )

    XCTAssertTrue(context.budget.didFallBackToDigest,
                  "level-1 fallback should mark didFallBackToDigest")
    // After the fallback, journal-related entries should be absent or trimmed.
    XCTAssertFalse(context.loadedFiles.contains(where: { $0.contains("journal/") }),
                   "level-1 fallback should drop journal entries")
}

func test_fallback_level2_dropsLowImportanceMemory() async throws {
    let bot = try await loadFixtureBot(named: "full-budget-bot")
    let assembler = ContextAssembler(bot: bot, store: BotStore())
    let context = try await assembler.assemble(
        mode: .fallback(level: 2, base: .conversation(userPrompt: "hello"))
    )
    XCTAssertTrue(context.budget.didFallBackToDigest)
    // memory/recent should be trimmed.
    XCTAssertLessThan(
        context.budget.breakdown["memory"] ?? 0,
        context.budget.breakdown["identity"] ?? 0,
        "level-2 fallback should leave memory smaller than identity"
    )
}

private func loadFixtureBot(named name: String) async throws -> Bot {
    let fixturesURL = Bundle.module.resourceURL!
        .appendingPathComponent("Fixtures/\(name)")
    let store = BotStore()
    return try await store.load(at: fixturesURL)
}
```

- [ ] **Step 36.3 [VERIFY]: Run the test — it should fail (assembler still fatalErrors on `.fallback`)**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter ContextAssemblerTests/test_fallback 2>&1 | tail -15
```

Expected: crash or build error.

- [ ] **Step 36.4 [CC]: Implement `.fallback` mode in `ContextAssembler`**

In `b0tKit/Sources/b0tCore/Context/ContextAssembler.swift`, replace the `.fallback` case in `assemble`:

```swift
case .fallback(let level, let base):
    return try await assembleFallback(level: level, base: base)
```

Add the private method:

```swift
private func assembleFallback(level: Int, base: AssemblyMode.BaseMode) async throws -> AssembledContext {
    // Level 1: drop journal entries (we don't include them yet, but the level
    // also restricts memory/recent to the most recent observation).
    // Level 2: drop low-importance memory observations (in addition to L1).
    // Level 3: surface the overflow — minimal context, model is asked to
    // acknowledge in the b0t voice.
    switch base {
    case .conversation(let userPrompt):
        return try await assembleConversationFallback(level: level, userPrompt: userPrompt)
    case .heartbeat(let trigger, let missedGap):
        return try await assembleHeartbeatFallback(level: level, trigger: trigger, missedGap: missedGap)
    }
}

private func assembleConversationFallback(level: Int, userPrompt: String) async throws -> AssembledContext {
    let identityCore = try await bot.identity.core
    let identityPrinciples = try await bot.identity.principles

    let identityText: String
    let memoryText: String
    let breakdownExtras: [String: Int]

    switch level {
    case 1:
        // Drop journal; keep memory.
        let memoryCore = try await bot.memory.core
        identityText = [identityCore.prose, identityPrinciples.prose].joined(separator: "\n\n")
        memoryText = memoryCore.prose
        breakdownExtras = [:]
    case 2:
        // Drop low-importance memory; keep only identity/core summary.
        identityText = identityCore.prose
        memoryText = "(memory trimmed)"
        breakdownExtras = [:]
    default:
        // Level 3: surface the overflow.
        identityText = "(identity trimmed)"
        memoryText = "(memory trimmed)"
        breakdownExtras = [:]
    }

    let systemInstructions = """
    you are the b0t named '\(bot.rootURL.lastPathComponent)'.

    identity:
    \(identityText)

    what you remember about the user:
    \(memoryText)
    """

    let prompt: String
    if level >= 3 {
        prompt = "you have lost most of your context. acknowledge this briefly to the user in your voice and ask them to repeat the essential."
    } else {
        prompt = userPrompt
    }

    let identityTokens = TokenEstimator.estimate(identityText)
    let memoryTokens = TokenEstimator.estimate(memoryText)
    let promptTokens = TokenEstimator.estimate(prompt)
    let total = identityTokens + memoryTokens + promptTokens

    let budget = TokenBudget(
        estimated: total,
        limit: Self.limit,
        breakdown: [
            "identity": identityTokens,
            "memory": memoryTokens,
            "userPrompt": promptTokens,
        ].merging(breakdownExtras) { a, _ in a },
        didFallBackToDigest: true
    )

    return AssembledContext(
        systemInstructions: systemInstructions,
        userPrompt: prompt,
        tools: [TimeAwarenessTool()],
        budget: budget,
        loadedFiles: ["identity/core.md", "identity/principles.md"]
    )
}

private func assembleHeartbeatFallback(
    level: Int,
    trigger: TickTrigger,
    missedGap: Duration?
) async throws -> AssembledContext {
    // Heartbeat fallback is similar shape to conversation fallback, just with
    // a tick-flavoured prompt at level 3.
    let identityCore = try await bot.identity.core
    let identityText = identityCore.prose

    let systemInstructions = """
    you are the b0t named '\(bot.rootURL.lastPathComponent)'.

    identity:
    \(identityText)

    (memory and actions trimmed for budget)
    """

    let prompt: String
    if level >= 3 {
        prompt = "your context overflowed. produce a minimal TickDecision with decided: 'pass' and acted: 'noted silently'."
    } else {
        prompt = "you woke from a \(trigger.rawValue) beat. produce a TickDecision."
    }

    let total = TokenEstimator.estimate(identityText) + TokenEstimator.estimate(prompt)

    let budget = TokenBudget(
        estimated: total,
        limit: Self.limit,
        breakdown: ["identity": TokenEstimator.estimate(identityText), "userPrompt": TokenEstimator.estimate(prompt)],
        didFallBackToDigest: true
    )

    return AssembledContext(
        systemInstructions: systemInstructions,
        userPrompt: prompt,
        tools: [TimeAwarenessTool()],
        budget: budget,
        loadedFiles: ["identity/core.md"]
    )
}
```

- [ ] **Step 36.5 [CC]: Update `ConversationManager.respond` to retry on `.exceededContextWindowSize`**

In `b0tKit/Sources/b0tCore/ConversationManager.swift`, replace `respond(to:)` with a retry-on-overflow version:

```swift
public func respond(to userPrompt: String) async throws -> ConversationResponse {
    if !didLoadTurnNumber {
        nextTurnNumber = await loadNextTurnNumber()
        didLoadTurnNumber = true
    }
    let turnNumber = nextTurnNumber
    nextTurnNumber += 1

    let response = try await respondWithFallback(
        userPrompt: userPrompt, level: 0
    )

    let delta = try await executor.apply(response)
    try await journalWriter.appendConversationTurn(
        prompt: userPrompt,
        response: response,
        stateDelta: delta,
        turnNumber: turnNumber
    )
    return response
}

private func respondWithFallback(userPrompt: String, level: Int) async throws -> ConversationResponse {
    let mode: AssemblyMode = (level == 0)
        ? .conversation(userPrompt: userPrompt)
        : .fallback(level: level, base: .conversation(userPrompt: userPrompt))
    let context = try await assembler.assemble(mode: mode)

    do {
        return try await client.generate(context: context, generating: ConversationResponse.self)
    } catch LanguageModelClientError.exceededContextWindowSize {
        if level >= 3 {
            // Final fallback: surface in b0t voice.
            return ConversationResponse(
                text: "oh — let me start fresh, I was getting muddled.",
                mood: .thinking,
                memoryObservations: []
            )
        }
        return try await respondWithFallback(userPrompt: userPrompt, level: level + 1)
    }
}
```

- [ ] **Step 36.6 [VERIFY]: Run all tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --no-parallel 2>&1 | tail -15
```

Expected: all pass, including the two new fallback tests.

- [ ] **Step 36.7 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Context/ContextAssembler.swift \
        b0tKit/Sources/b0tCore/ConversationManager.swift \
        b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift \
        b0tKit/Tests/b0tCoreTests/Fixtures/full-budget-bot/
git commit -m "feat(b0tCore): graduated context-overflow fallback

ContextAssembler.assemble(.fallback(level:base:)) implements three levels
of progressive content trimming. ConversationManager retries with
incrementing levels on .exceededContextWindowSize and finally surfaces
in the b0t's voice ('oh — let me start fresh, I was getting muddled').
HeartbeatManager surfaces overflow as .errored — heartbeats are
best-effort. See spec §7.4."
```

---

### Task 37: `JournalWriter.appendError` (replaces the placeholder)

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Apply/JournalWriter.swift`
- Modify: `b0tKit/Sources/b0tCore/HeartbeatManager.swift`
- Modify: `b0tKit/Sources/b0tCore/ConversationManager.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift`

- [ ] **Step 37.1 [CC]: Add the byte-exact test**

Append to `b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift`:

```swift
func test_appendError_turn_writesByteExactEntry() async throws {
    let bot = try await loadCanonicalBotInTempCopy()
    let store = BotStore()
    let date = ISO8601DateFormatter().date(from: "2026-05-01T14:33:00Z")!
    let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

    try await writer.appendError(
        error: LanguageModelClientError.modelUnavailable,
        kind: .turn(number: 8)
    )

    let content = try String(contentsOf: writer.journalURL(for: date), encoding: .utf8)
    let expected = """
    ---
    date: 2026-05-01
    ---

    ## 14:33 — turn 8 — error

    **error:** modelUnavailable
    **state_delta:** none

    """
    XCTAssertEqual(content, expected)
}

func test_appendError_heartbeat_writesByteExactEntry() async throws {
    let bot = try await loadCanonicalBotInTempCopy()
    let store = BotStore()
    let date = ISO8601DateFormatter().date(from: "2026-05-01T15:00:00Z")!
    let writer = JournalWriter(bot: bot, store: store, clock: FixedClock(date))

    struct Boom: Error, CustomStringConvertible {
        var description: String { "boom" }
    }
    try await writer.appendError(
        error: Boom(),
        kind: .heartbeat(number: 247)
    )

    let content = try String(contentsOf: writer.journalURL(for: date), encoding: .utf8)
    let expected = """
    ---
    date: 2026-05-01
    ---

    ## 15:00 — heartbeat 247 — error

    **error:** boom
    **state_delta:** none

    """
    XCTAssertEqual(content, expected)
}
```

- [ ] **Step 37.2 [CC]: Implement `appendError` (replace the placeholder)**

Replace the placeholder `appendError` body in `b0tKit/Sources/b0tCore/Apply/JournalWriter.swift`:

```swift
public func appendError(
    error: Error,
    kind: EntryKind
) async throws {
    let date = clock.now()
    let timeString = Self.timeString(for: date)
    let header: String
    switch kind {
    case .turn(let n): header = "## \(timeString) — turn \(n) — error"
    case .heartbeat(let n): header = "## \(timeString) — heartbeat \(n) — error"
    }
    let errorText = describeError(error)
    let entry = """
    \(header)

    **error:** \(errorText)
    **state_delta:** none
    """
    try await appendRaw(entry, for: date)
}

private func describeError(_ error: Error) -> String {
    if let lme = error as? LanguageModelClientError {
        switch lme {
        case .modelUnavailable: return "modelUnavailable"
        case .exceededContextWindowSize(let n): return "exceededContextWindowSize(\(n))"
        case .sessionFailed(let d): return "sessionFailed: \(d)"
        case .malformedGenerableOutput(let d): return "malformedGenerableOutput: \(d)"
        }
    }
    if let described = (error as? CustomStringConvertible)?.description {
        return described
    }
    return String(describing: error)
}
```

Wait — `appendError` is currently a placeholder thrower added in Task 19? Let me check — no, looking back I see Task 19 added `appendTick` and `appendSuppressed` placeholders, then Tasks 20 and 24 replaced them. `appendError` was declared in the spec (§5.6) but I haven't added a placeholder for it yet. So the impl above is the first appearance — adjust the prose accordingly: "Add `appendError` to JournalWriter."

- [ ] **Step 37.3 [CC]: Wire `appendError` into `HeartbeatManager` and `ConversationManager`**

In `HeartbeatManager.tick(trigger:)`, replace the `catch` block:

```swift
} catch {
    Self.logger.error("heartbeat tick failed: \(String(describing: error))")
    try? await journalWriter.appendError(error: error, kind: .heartbeat(number: beatNumber))
    return .errored(message: String(describing: error))
}
```

In `ConversationManager.respond(to:)`, wrap the orchestration in a do/catch:

```swift
public func respond(to userPrompt: String) async throws -> ConversationResponse {
    if !didLoadTurnNumber {
        nextTurnNumber = await loadNextTurnNumber()
        didLoadTurnNumber = true
    }
    let turnNumber = nextTurnNumber
    nextTurnNumber += 1

    do {
        let response = try await respondWithFallback(userPrompt: userPrompt, level: 0)
        let delta = try await executor.apply(response)
        try await journalWriter.appendConversationTurn(
            prompt: userPrompt, response: response, stateDelta: delta, turnNumber: turnNumber
        )
        return response
    } catch {
        try? await journalWriter.appendError(error: error, kind: .turn(number: turnNumber))
        throw error
    }
}
```

- [ ] **Step 37.4 [VERIFY]: Run all tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --no-parallel 2>&1 | tail -15
```

Expected: all pass.

- [ ] **Step 37.5 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/Apply/JournalWriter.swift \
        b0tKit/Sources/b0tCore/HeartbeatManager.swift \
        b0tKit/Sources/b0tCore/ConversationManager.swift \
        b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift
git commit -m "feat(b0tCore): JournalWriter.appendError + wire into both managers

Adds the kind-discriminated appendError (turn vs. heartbeat). HeartbeatManager
writes a heartbeat-error entry on any catch-all path; ConversationManager
writes a turn-error entry then re-throws (callers may want to surface).
LanguageModelClientError gets a human-readable describeError mapping.
See spec §5.6, §7.3, §8."
```

---

### Task 38: Live integration tests (gated on FM availability)

**Files:**
- Create: `b0tKit/Tests/b0tCoreIntegrationTests/LiveModelConversationTest.swift`
- Create: `b0tKit/Tests/b0tCoreIntegrationTests/LiveModelTickTest.swift`
- Delete: `b0tKit/Tests/b0tCoreIntegrationTests/_Tombstone.swift`

**Why now:** Spec §9.3 requires two integration tests gated on `requiresFoundationModels`. They run against the production `default-bot/`, on a real device or a simulator with FM enabled.

- [ ] **Step 38.1 [CC]: Delete the tombstone**

```bash
rm /Users/haydentoppeross/development/b0t/b0tKit/Tests/b0tCoreIntegrationTests/_Tombstone.swift
```

- [ ] **Step 38.2 [CC]: Write `LiveModelConversationTest`**

`b0tKit/Tests/b0tCoreIntegrationTests/LiveModelConversationTest.swift`:

```swift
import XCTest
import FoundationModels
@testable import b0tCore
@testable import b0tBrain

final class LiveModelConversationTest: XCTestCase {
    func test_oneConversationTurn_completesAgainstRealModel() async throws {
        try requireFoundationModelsAvailable()

        let bot = try await loadProductionDefaultBotInTempCopy()
        let store = BotStore()
        let client = try LiveLanguageModelClient()
        let manager = ConversationManager(bot: bot, store: store, client: client)

        let response = try await manager.respond(to: "say hi in one sentence")

        XCTAssertFalse(response.text.isEmpty, "expected a non-empty reply")

        // Journal entry written.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let day = formatter.string(from: Date())
        let journalURL = bot.journal.directoryURL.appendingPathComponent("\(day).md")
        let journal = try String(contentsOf: journalURL, encoding: .utf8)
        XCTAssertTrue(journal.contains("turn 1"))
    }

    private func requireFoundationModelsAvailable() throws {
        guard SystemLanguageModel.default.isAvailable else {
            throw XCTSkip("Foundation Models is not available on this test runner")
        }
    }

    private func loadProductionDefaultBotInTempCopy() async throws -> Bot {
        // Repo-relative path: b0tKit/Tests/b0tCoreIntegrationTests/<this file> → b0tKit/ → repo
        let here = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let defaultBot = here.appendingPathComponent("default-bot")
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("b0t-01")
        try FileManager.default.createDirectory(
            at: temp.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: defaultBot, to: temp)
        addTeardownBlock { try? FileManager.default.removeItem(at: temp.deletingLastPathComponent()) }

        let store = BotStore()
        return try await store.load(at: temp)
    }
}
```

- [ ] **Step 38.3 [CC]: Write `LiveModelTickTest`**

`b0tKit/Tests/b0tCoreIntegrationTests/LiveModelTickTest.swift`:

```swift
import XCTest
import FoundationModels
@testable import b0tCore
@testable import b0tBrain

final class LiveModelTickTest: XCTestCase {
    func test_oneHeartbeatTick_completesAgainstRealModel() async throws {
        try requireFoundationModelsAvailable()

        let bot = try await loadProductionDefaultBotInTempCopy()
        let store = BotStore()
        let client = try LiveLanguageModelClient()
        let manager = HeartbeatManager(bot: bot, store: store, client: client)

        let result = try await manager.tick(trigger: .manual)

        switch result {
        case .decided(let d):
            XCTAssertFalse(d.observed.isEmpty)
            XCTAssertFalse(d.decided.isEmpty)
        case .suppressed(let reason):
            // .quietHours is plausible if the test runs during the canonical quiet window.
            XCTAssertEqual(reason, .quietHours, "model unavailable but available check passed?")
        case .errored(let msg):
            XCTFail("tick errored: \(msg)")
        }
    }

    private func requireFoundationModelsAvailable() throws {
        guard SystemLanguageModel.default.isAvailable else {
            throw XCTSkip("Foundation Models is not available on this test runner")
        }
    }

    private func loadProductionDefaultBotInTempCopy() async throws -> Bot {
        let here = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let defaultBot = here.appendingPathComponent("default-bot")
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("b0t-01")
        try FileManager.default.createDirectory(
            at: temp.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: defaultBot, to: temp)
        addTeardownBlock { try? FileManager.default.removeItem(at: temp.deletingLastPathComponent()) }

        let store = BotStore()
        return try await store.load(at: temp)
    }
}
```

- [ ] **Step 38.4 [VERIFY]: Run the integration tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter b0tCoreIntegrationTests 2>&1 | tail -15
```

Expected: on a host without FM (most CI runners), both tests skip with the documented reason. On a real device with FM, both pass.

- [ ] **Step 38.5 [CC]: Commit**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Tests/b0tCoreIntegrationTests/
git commit -m "test(b0tCore): live-FM integration tests for conversation + tick

LiveModelConversationTest and LiveModelTickTest run one full flow each
against the real LanguageModelSession on the production default-bot
(provisioned to a temp directory). XCTSkip when SystemLanguageModel is
unavailable so CI without FM passes. See spec §9.3."
```

---

### Task 39: `DebugBrainView` final pass — voice-and-copy compliance

**Files:**
- Modify: `b0tApp/Sources/Debug/DebugBrainView.swift`

**Why now:** PRD §6 voice guide applies to every user-facing string. The debug view is DEBUG-only but still has copy that should be lowercase / functional / no exclamation marks per the guide.

- [ ] **Step 39.1 [CC]: Walk through every string in `DebugBrainView` against `docs/references/voice-and-copy-guide.md`**

Read `/Users/haydentoppeross/development/b0t/docs/references/voice-and-copy-guide.md`. Then audit:

- "initializing model..." → ✓ lowercase, period.
- "stub mode — \(reason)" → ✓ lowercase. Check that reason strings are also lowercase.
- "model unavailable on this device" → ✓.
- "--use-stub-client launch arg" → ✓.
- "init failed: \(error)" → ✓.
- "stub does not handle \(outputType)" → preconditionFailure, never user-facing.
- "(stub) heard you" → ✓ lowercase.
- "stub tick" → ✓.
- "(journal empty)" → ✓.
- "♥ firing heartbeat..." → unicode heart in user-facing. The aesthetic allows ASCII-art glyphs (per design doc). Keep.
- "♥ \(d.decided): \(d.acted)" → ✓.
- "♥ suppressed (\(reason.rawValue))" → ✓.
- "♥ errored: \(msg)" → ✓.
- "♥ tick threw: \(error)" → ✓.
- Button labels: "send", "close", "♥" → ✓ lowercase.
- Title: "debug brain" → ✓.
- Banner: "stub mode — model unavailable on this device" → ✓.

- [ ] **Step 39.2 [VERIFY]: Build + manual smoke**

```bash
cd /Users/haydentoppeross/development/b0t
xcrun xcodebuild build \
    -project b0t.xcodeproj \
    -scheme b0t \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug \
    2>&1 | tail -15
```

Expected: BUILD SUCCEEDED.

Run on simulator. Verify all visible strings are lowercase (or intentional unicode like ♥) and free of exclamation marks.

- [ ] **Step 39.3 [CC]: If the audit found any non-compliant strings, fix them**

If anything was non-compliant (e.g., "Click to send!" in a button label), rewrite to comply with the guide.

If everything was already compliant, this step is a no-op — proceed to commit (or skip the commit if there are no changes).

- [ ] **Step 39.4 [CC]: Commit (only if changes were made)**

```bash
cd /Users/haydentoppeross/development/b0t
git diff --stat b0tApp/Sources/Debug/DebugBrainView.swift
# If diff is empty, skip commit. Otherwise:
git add b0tApp/Sources/Debug/DebugBrainView.swift
git commit -m "polish(b0tApp): voice-and-copy audit pass on DebugBrainView

Walked every user-facing string in DebugBrainView through
docs/references/voice-and-copy-guide.md. (No changes needed | adjusted X
strings to comply with lowercase/functional/no-exclamation rules.)"
```

---

### Task 40: `b0tCore/CLAUDE.md` refresh + `IMPLEMENTATION.md` update + privacy audit + design doc follow-up note

**Files:**
- Modify: `b0tKit/Sources/b0tCore/CLAUDE.md`
- Modify: `docs/IMPLEMENTATION.md`

**Why now:** End of phase. The CLAUDE.md should describe the as-built API; the implementation tracker advances Phase 2 to complete; a privacy audit confirms no new network calls; the follow-up doc PR for design doc §5.4 is recorded.

- [ ] **Step 40.1 [CC]: Replace `b0tCore/CLAUDE.md` with the as-built doc**

Replace `/Users/haydentoppeross/development/b0t/b0tKit/Sources/b0tCore/CLAUDE.md`:

```markdown
# b0tCore

The Foundation Models loop. Owns the lifecycle of `LanguageModelSession` instances, the `ContextAssembler`, and the `@Generable` decision types that the model returns.

## Public API contracts (as-built, Phase 2)

- `ConversationManager` — actor; `respond(to:) async throws -> ConversationResponse`. Orchestrates assemble → client → executor → journal. Retries on `.exceededContextWindowSize` via graduated fallback.
- `HeartbeatManager` — actor; `register()`, `tick(trigger:) async throws -> TickResult`, `scheduleNext() async throws`. DEBUG-only `startDebugTimer()` / `stopDebugTimer()`.
- `LanguageModelClient` protocol; `LiveLanguageModelClient` (wraps `LanguageModelSession`) and `StubLanguageModelClient` (test seam).
- `ContextAssembler` — assembles `.conversation` / `.heartbeat` / `.fallback` modes. Token-budget logged in DEBUG via OSLog.
- `@Generable` types: `ConversationResponse`, `TickDecision`, `MemoryObservation`, `RelationshipNote`, `MoodTransition` (last two ship as types but aren't exercised in Phase 2).
- `Executor` — applies decisions to `BotStore` (memory observations to `memory/recent.md`, would-notify capture for Phase 4+ posting).
- `JournalWriter` — OpenClaw-format appends in four variants (turn, heartbeat, suppressed, error).
- `HeartbeatSchedule` — frontmatter parser for `schedule.md` (BPM, quiet hours, event triggers).
- `MissedBeatDetector` — duration since last journal entry's timestamp.
- `TimeAwarenessTool` — sole `Tool` shipped in Phase 2; Phase 3 wires real skill bridges.
- `HeartbeatScheduler` protocol; `LiveBGTaskScheduler` (wraps `BGTaskScheduler.shared`) and `FakeHeartbeatScheduler` (DEBUG-only, for unit tests).

## Patterns

- Every model call is a fresh session with assembled context. State persists in markdown files (`b0tBrain`), not in session memory.
- Token counts use the `TokenEstimator` (4-chars-per-token heuristic). The graduated overflow fallback is the actual safety net.
- Conversation turns AND heartbeat ticks both append OpenClaw entries to `journal/YYYY-MM-DD.md`. Resolves PRD §3.2 vs design doc §5.4 ambiguity in PRD's favour. (Design doc §5.4 follow-up doc PR pending — see `docs/IMPLEMENTATION.md` Phase 2 notes.)
- BG-task arithmetic is unit-tested via `FakeHeartbeatScheduler`. The actual fact-of-firing is verified manually on real device.

## DEBUG launch args (recognised by `DebugBrainView` and `b0tApp`)

- `--use-stub-client` — force the stub client even when FM is available.
- `--debug-heartbeat-timer` — replace BG-task scheduling with a `Task` loop that fires `tick(.scheduled)` at `bpm/4` (floored to 15s).

Both args are app-side only; production `@main` code path uses live clients and live scheduler.

## Manual smoke checklist (slice-10 acceptance — required for phase close)

1. Simulator with `--debug-heartbeat-timer`: `DebugBrainView` chats via stub, ♥ button fires manual ticks, debug timer fires automatic ticks every 15s. Journal-tail pane grows.
2. Real device with Apple Intelligence enabled: live FM replies, ♥ tick fires successfully, BG task fires within OS-allowed window (LLDB trick to force-fire: `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.b0t.heartbeat"]`).

## Depends on

- `b0tBrain` (markdown reads/writes)
- `FoundationModels` (system, iOS 26)
- `BackgroundTasks` (system, iOS 26)

## Does NOT depend on

- `b0tFace`, `b0tAudio`, `b0tDesign` (UI/output concerns belong in the app target or face/audio packages)
- `b0tSkills` (Phase 3 — `b0tCore` exposes `AssembledContext.tools` as the integration point)

## Read first when working here

- `docs/specs/phase-2-foundation-models-loop.md` — design contract
- `docs/prd.md` §3.3, §3.4, §5.2, §5.6
- `docs/decisions/0001-on-device-only.md`, `0005-three-file-identity.md`
```

- [ ] **Step 40.2 [CC]: Update `docs/IMPLEMENTATION.md`**

Edit `/Users/haydentoppeross/development/b0t/docs/IMPLEMENTATION.md`:

Replace the "Current state" block:

```markdown
## Current state

- **Phase:** 3 — Skill bridges
- **Status:** not started
- **Plan:** (forthcoming — will live at `docs/plans/phase-3-*.md`)
```

Update the phase ledger row for Phase 2:

```markdown
| 2 | Foundation Models loop | [phase-2](plans/phase-2-foundation-models-loop.md) | complete (2026-05-XX) |
```

(Replace `XX` with the actual day-of-month when Phase 2 closes.)

Add a new section at the bottom:

```markdown
## Notes from Phase 2

- Spec at `docs/specs/phase-2-foundation-models-loop.md` settled five design questions during brainstorming (scope shape, acceptance demo bar, model-layer testability, demo surface, conversation-turns-also-journal). Plan at `docs/plans/phase-2-foundation-models-loop.md` decomposed the spec into 40 walking-skeleton tasks across 10 slices.
- Final shape: b0tCore module with ~25 public types, full unit-test coverage via `StubLanguageModelClient`, two gated live-FM integration tests against the production `default-bot/`.
- No new third-party SPM dependencies. `FoundationModels` and `BackgroundTasks` are system-provided (iOS 26).
- Privacy audit: confirmed zero new network calls. `LanguageModelSession` is on-device per Apple's design; `BGTaskScheduler` is a system service. No telemetry, no analytics. Privacy posture intact.
- Decision (i) — conversation turns also produce OpenClaw journal entries — resolves a PRD §3.2 vs design doc §5.4 ambiguity in PRD's favour. **Follow-up doc PR pending:** update design doc §5.4 to read "Each heartbeat or conversation turn appends an entry…".
- Phase 1 note about "first spec planned: `context-assembler.md` during Phase 2 prep" is closed — subsumed by the Phase 2 spec. Removed from "Specs in flight."
```

Update "Specs in flight":

```markdown
## Specs in flight

- (none currently — Phase 3 spec to be brainstormed when phase begins)
```

- [ ] **Step 40.3 [VERIFY]: Run the full test suite + simulator build**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --no-parallel 2>&1 | tail -10

cd /Users/haydentoppeross/development/b0t
xcrun xcodebuild build \
    -project b0t.xcodeproj \
    -scheme b0t \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug \
    2>&1 | tail -15
```

Expected: all tests pass (Phase 1 + Phase 2 unit + integration with FM-skip), simulator build succeeds.

- [ ] **Step 40.4 [VERIFY]: Privacy audit — confirm no new network calls in any new file**

```bash
cd /Users/haydentoppeross/development/b0t
grep -rn -E "URLSession|URL\(string:|http://|https://" \
    b0tKit/Sources/b0tCore/ b0tApp/Sources/Debug/ \
    | grep -v "^Binary" \
    || echo "(no matches — privacy clean)"
```

Expected: only matches in @Guide descriptions (literal strings — these are prompt content, not network calls), or no matches. If a real `URLSession` use appears, that's a regression — investigate before continuing.

- [ ] **Step 40.5 [VERIFY]: swift-format lint**

```bash
cd /Users/haydentoppeross/development/b0t
swift format lint --strict --recursive \
    b0tKit/Sources/b0tCore/ \
    b0tKit/Tests/b0tCoreTests/ \
    b0tKit/Tests/b0tCoreIntegrationTests/ \
    b0tApp/Sources/Debug/ \
    2>&1 | tail -10
```

Expected: clean output. Fix any reported issues before committing.

- [ ] **Step 40.6 [CC]: Commit the doc updates**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/Sources/b0tCore/CLAUDE.md docs/IMPLEMENTATION.md
git commit -m "docs: mark Phase 2 complete, refresh b0tCore/CLAUDE.md to as-built API

Replaces the Phase-0 placeholder b0tCore/CLAUDE.md with the as-built API
inventory. IMPLEMENTATION.md advances Phase 2 → complete and Phase 3 →
next; adds a Notes from Phase 2 section covering spec decisions,
test-coverage summary, privacy-audit confirmation, and the follow-up
doc PR for design doc §5.4."
```

- [ ] **Step 40.7 [VERIFY]: Manual smoke — full slice-10 acceptance (required for phase close)**

Walk the manual smoke checklist from `b0tCore/CLAUDE.md` in full:

1. Simulator with `--debug-heartbeat-timer`:
   - Launch app, tap "debug brain".
   - Stub-mode banner shows.
   - Type "hello" → see canned reply, journal grows with turn 1.
   - Tap ♥ → status line "♥ pass: noted silently", journal grows with heartbeat 1.
   - Wait 15+ seconds → automatic heartbeat fires, journal grows with heartbeat 2.

2. Real device with Apple Intelligence enabled (no launch args):
   - Launch app, tap "debug brain". No stub-mode banner.
   - Type "hello" → see real FM reply.
   - Tap ♥ → real FM produces a TickDecision; journal grows with the OpenClaw entry.
   - Background the app, wait ~10 minutes; foreground; check `journal/YYYY-MM-DD.md` via Files app — `BGAppRefreshTask` should have fired at least once.
   - (Optional, faster) Use Xcode LLDB trick to force-fire BG task and observe.

Document the smoke results in the phase-close PR description:

```
Manual smoke (per b0tCore/CLAUDE.md slice-10 acceptance):
- [x] Simulator with --debug-heartbeat-timer: stub mode, manual ticks, automatic timer ticks all work; journal grows correctly.
- [x] Real device (iPhone 15 Pro, Apple Intelligence enabled): live FM reply, manual heartbeat with TickDecision, BG task fires within OS-allowed window.
```

If any step fails, do NOT close the phase. Investigate, file a follow-up issue, and decide whether to extend Phase 2 or punt to Phase 3+.

---

## End of Phase 2 — Final checks before merging the phase

Open a single PR titled "Phase 2: Foundation Models loop" containing all 40 task commits (or one PR per slice if Jamee prefers smaller reviews). The PR description must include:

- Reference to PRD §4 Phase 2 + §5.2 + §5.6 + §3.3 + §3.4.
- Reference to `docs/specs/phase-2-foundation-models-loop.md`.
- The manual-smoke checklist above with checked boxes.
- Privacy-audit confirmation: "No new network calls. FoundationModels is on-device. BackgroundTasks is a system service."
- Note about the pending design-doc §5.4 follow-up PR.

After merge:

1. Run `/audit` slash command for App Store readiness sanity (probably premature this far before Phase 10, but harmless).
2. Open the design-doc §5.4 follow-up doc PR.
3. Brainstorm Phase 3 — Skill bridges.

*end of Phase 2 implementation plan.*









