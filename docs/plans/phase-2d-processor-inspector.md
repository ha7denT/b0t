# Stage D — Processor Inspector + Token Metering — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the inference engine work visible and interactive — a full Processor organ inspector (switch models, drive downloads), per-turn token metering on the face crown and in Controls, and the plumbing to swap the live engine mid-session.

**Architecture:** Approach A — an `EngineHost` indirection (a swappable `InferenceEngine` wrapper) lets the live managers keep a stable engine reference while the inner engine swaps on model change. Token usage is a per-turn snapshot (`GenerationUsage`) emitted on a Combine subject, mirroring the existing `toolCallEvents`. The Processor inspector binds to two dependency-inverted seams (`ProcessorControlling`, `ModelDownloadServicing`) defined in `b0tHome` and implemented in `b0tApp`, keeping the GUI module free of the llama binary.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI, Combine, swift-testing/XCTest (SPM `swift test`), `OSAllocatedUnfairLock` (`import os`), existing `b0tCore`/`b0tBrain`/`b0tLlama`/`b0tHome` modules.

---

## Module-placement corrections (vs. the design spec)

The design spec (`docs/specs/phase-2-stage-d-processor-inspector.md`) named `EngineHost` as living in `b0tCore`. That is not buildable: `EngineHost` needs `ModelStore`/`LlamaEngine` (in `b0tLlama`), and `b0tCore` cannot depend on `b0tLlama` (circular). Corrections, faithful to approach A:

- **`EngineHost`** → `b0tLlama` (it already depends on `b0tCore`; it can see both engines + `ModelStore`). The managers reference it only through the `InferenceEngine` protocol.
- **`GenerationUsage`, `ModelSelectionOutcome`, `usageEvents`** → `b0tCore` (no new deps).
- **`ProcessorControlling`, `ModelDownloadServicing`, `ModelDownloadCoordinator`, `ProcessorInspectionView`, crown view** → `b0tHome`. Concrete conformers (`AppProcessorController`, `AppModelDownloadService`) and the shared `EngineHost` construction → `b0tApp`.

The `OrganID` case for the Processor organ is `.reasoning` (the enum case keeps its original name; only the user-facing label changed to "Processor" per ADR-0017). All dispatch code references `.reasoning`.

---

## File structure

**Create**
- `b0tKit/Sources/b0tCore/Model/GenerationUsage.swift` — the per-turn usage snapshot + `ModelSelectionOutcome`.
- `b0tKit/Sources/b0tLlama/EngineHost.swift` — swappable engine wrapper.
- `b0tKit/Sources/b0tHome/Processor/ProcessorControlling.swift` — switch/select seam protocol.
- `b0tKit/Sources/b0tHome/Processor/ModelDownloadServicing.swift` — download backend seam protocol.
- `b0tKit/Sources/b0tHome/Processor/ModelDownloadCoordinator.swift` — `@Observable` UI state for downloads.
- `b0tKit/Sources/b0tHome/Processor/ProcessorInspectionView.swift` — the 3-tab inspector.
- `b0tKit/Sources/b0tHome/Processor/CrownTokenMetersView.swift` — the two crown bars.
- `b0tKit/Sources/b0tHome/Internal/UsageListener.swift` — subscribes `usageEvents` → `AnatomyState.latestUsage`.
- `b0tApp/Sources/App/Processor/AppProcessorController.swift` — `ProcessorControlling` over `EngineHost` + `BotStore`.
- `b0tApp/Sources/App/Processor/AppModelDownloadService.swift` — `ModelDownloadServicing` over `ModelDownloadManager`.
- Test files mirrored under `b0tKit/Tests/<module>Tests/...`.

**Modify**
- `b0tKit/Sources/b0tCore/Context/ContextAssembler.swift` — read context window live via a provider.
- `b0tKit/Sources/b0tCore/ConversationManager.swift` — add `usageEvents`, emit per turn.
- `b0tKit/Sources/b0tCore/HeartbeatManager.swift` — add `usageEvents`, emit per beat.
- `b0tKit/Sources/b0tHome/AnatomyState.swift` — hold `latestUsage`, the two seams.
- `b0tKit/Sources/b0tHome/InspectionPanel.swift:55` — dispatch `.reasoning` to `ProcessorInspectionView`.
- `b0tKit/Sources/b0tHome/Synthesised/ReasoningStateFile.swift` — delete (replaced).
- `b0tApp/Sources/App/b0tApp.swift` — build a shared `EngineHost`; inject seams.

---

## Slice 1 — Engine swap foundation

### Task 1: `ModelSelectionOutcome` + `GenerationUsage` value types

**Files:**
- Create: `b0tKit/Sources/b0tCore/Model/GenerationUsage.swift`
- Test: `b0tKit/Tests/b0tCoreTests/GenerationUsageTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import b0tCore

final class GenerationUsageTests: XCTestCase {
    func test_fractionUsed_isInputPlusOutputOverLimit() {
        let usage = GenerationUsage(
            tokensIn: 1500, tokensOut: 500, limit: 4000, modelId: "qwen3-1.7b",
            breakdown: ["identity/core.md": 800])
        XCTAssertEqual(usage.totalTokens, 2000)
        XCTAssertEqual(usage.fractionUsed, 0.5, accuracy: 0.0001)
    }

    func test_fractionUsed_zeroLimit_isZero() {
        let usage = GenerationUsage(
            tokensIn: 10, tokensOut: 10, limit: 0, modelId: "x", breakdown: [:])
        XCTAssertEqual(usage.fractionUsed, 0)
    }

    func test_modelSelectionOutcome_equatable() {
        XCTAssertEqual(ModelSelectionOutcome.active(modelId: "a"), .active(modelId: "a"))
        XCTAssertNotEqual(ModelSelectionOutcome.active(modelId: "a"), .missing(modelId: "a"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd b0tKit && swift test --filter GenerationUsageTests`
Expected: FAIL — `cannot find 'GenerationUsage' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

/// A per-turn token-usage snapshot, emitted by `ConversationManager`/`HeartbeatManager`
/// after a turn or beat completes. Drives the crown meters and the Processor
/// Controls token gauge. Snapshot-per-turn (no live streaming) — see
/// `docs/specs/phase-2-stage-d-processor-inspector.md` §5.
public struct GenerationUsage: Sendable, Equatable {
    /// Assembled-prompt tokens (`TokenBudget.estimated`).
    public let tokensIn: Int
    /// Response tokens (`TokenEstimator` over the final response text).
    public let tokensOut: Int
    /// Shared ceiling — the active model's effective budget (`TokenBudget.limit`).
    public let limit: Int
    /// Resolved model id at turn time (empty if unknown).
    public let modelId: String
    /// Per-slot/per-organ subtotals (`TokenBudget.breakdown`).
    public let breakdown: [String: Int]

    public init(
        tokensIn: Int, tokensOut: Int, limit: Int, modelId: String,
        breakdown: [String: Int]
    ) {
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.limit = limit
        self.modelId = modelId
        self.breakdown = breakdown
    }

    public var totalTokens: Int { tokensIn + tokensOut }

    /// Total tokens as a fraction of the ceiling, clamped to `0...1`. Zero when
    /// `limit <= 0`.
    public var fractionUsed: Double {
        guard limit > 0 else { return 0 }
        return min(1.0, Double(totalTokens) / Double(limit))
    }
}

/// Outcome of a model-selection request. `.missing` tells the UI to bounce to
/// the Directory tab and offer the download (spec §2 — "immediate re-resolve + load").
public enum ModelSelectionOutcome: Sendable, Equatable {
    case active(modelId: String)
    case missing(modelId: String)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd b0tKit && swift test --filter GenerationUsageTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tCore/Model/GenerationUsage.swift b0tKit/Tests/b0tCoreTests/GenerationUsageTests.swift
git commit -m "feat(b0tCore): GenerationUsage + ModelSelectionOutcome value types (Stage D)"
```

---

### Task 2: `ContextAssembler` reads the context window live

The assembler currently captures `contextWindow` at init (`init(..., contextWindow: Int = 4096)` → stores `self.limit`). Stage D needs the limit to follow a live engine swap. Add a window *provider* and compute `limit` per-assembly. Keep the old initializer working (it wraps the constant in a closure) so existing call sites/tests compile unchanged.

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Context/ContextAssembler.swift:54-66`
- Test: `b0tKit/Tests/b0tCoreTests/ContextAssemblerWindowTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import b0tCore
import b0tBrain

final class ContextAssemblerWindowTests: XCTestCase {
    func test_limit_followsProvider_acrossAssemblies() async throws {
        let bot = try Bot.empty(at: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString))
        let store = BotStore()
        let windowBox = LockedWindowBox(4096)
        let assembler = ContextAssembler(
            bot: bot, store: store, tools: [], toolsRequirePermission: false,
            contextWindowProvider: { windowBox.value })

        let first = try await assembler.assemble(mode: .conversation(userPrompt: "hi"))
        XCTAssertEqual(first.budget.limit, 4096 - ContextAssembler.responseReserve)

        windowBox.value = 32768
        let second = try await assembler.assemble(mode: .conversation(userPrompt: "hi"))
        XCTAssertEqual(second.budget.limit, 32768 - ContextAssembler.responseReserve)
    }
}

/// Test-only mutable box (the production provider reads `EngineHost.contextWindow`).
final class LockedWindowBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Int
    init(_ v: Int) { _value = v }
    var value: Int {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); _value = newValue; lock.unlock() }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd b0tKit && swift test --filter ContextAssemblerWindowTests`
Expected: FAIL — `extra argument 'contextWindowProvider' in call`.

- [ ] **Step 3: Write minimal implementation**

In `ContextAssembler.swift`, replace the stored `limit` with a provider. Locate the stored property and initializer (around lines 50-66). Change:

```swift
    // was: public let limit: Int
    private let windowProvider: @Sendable () -> Int

    /// Effective budget limit = current window minus the response reserve.
    /// Read per-assembly so a live engine swap (Stage D EngineHost) takes effect.
    var limit: Int { max(0, windowProvider() - Self.responseReserve) }

    public init(
        bot: Bot,
        store: BotStore,
        tools: [any Tool],
        toolsRequirePermission: Bool,
        contextWindow: Int = 4096
    ) {
        self.init(
            bot: bot, store: store, tools: tools,
            toolsRequirePermission: toolsRequirePermission,
            contextWindowProvider: { contextWindow })
    }

    public init(
        bot: Bot,
        store: BotStore,
        tools: [any Tool],
        toolsRequirePermission: Bool,
        contextWindowProvider: @escaping @Sendable () -> Int
    ) {
        self.bot = bot
        self.store = store
        self.tools = tools
        self.toolsRequirePermission = toolsRequirePermission
        self.windowProvider = contextWindowProvider
    }
```

Leave every existing `self.limit` *read* inside the assemble methods untouched — they now read the computed property. Remove the old `self.limit = max(0, contextWindow - Self.responseReserve)` assignment line.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd b0tKit && swift test --filter ContextAssemblerWindowTests`
Expected: PASS.
Run: `cd b0tKit && swift test --filter b0tCoreTests`
Expected: PASS — no regressions in the existing assembler/budget tests.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tCore/Context/ContextAssembler.swift b0tKit/Tests/b0tCoreTests/ContextAssemblerWindowTests.swift
git commit -m "feat(b0tCore): ContextAssembler reads context window live via provider (Stage D)"
```

---

### Task 3: `EngineHost` — swappable engine wrapper

A `final class` (not an actor) so it can satisfy the synchronous `var contextWindow` requirement of `InferenceEngine` while still doing async swap/generate work. State is guarded by an `OSAllocatedUnfairLock`; the lock is only held to read/swap references, never across `await`.

**Files:**
- Create: `b0tKit/Sources/b0tLlama/EngineHost.swift`
- Test: `b0tKit/Tests/b0tLlamaTests/EngineHostTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import b0tCore
import b0tBrain
@testable import b0tLlama

final class EngineHostTests: XCTestCase {
    /// A stub engine that records its identity via contextWindow.
    struct StubEngine: InferenceEngine {
        let window: Int
        var contextWindow: Int { window }
        func generate<Output: StructuredOutput>(
            context: AssembledContext, generating outputType: Output.Type
        ) async throws -> (Output, [ToolCallRecord]) {
            throw InferenceEngineError.sessionFailed(underlyingDescription: "stub")
        }
    }

    func test_initialEngine_isForwarded() {
        let host = EngineHost(
            initialEngine: StubEngine(window: 4096), initialModelId: "foundation_models_default",
            loader: { _ in nil })
        XCTAssertEqual(host.contextWindow, 4096)
        XCTAssertEqual(host.activeModelId, "foundation_models_default")
    }

    func test_selectModel_loadsAndSwaps_whenLoaderReturnsEngine() async {
        let host = EngineHost(
            initialEngine: StubEngine(window: 4096), initialModelId: "foundation_models_default",
            loader: { id in id == "qwen3-1.7b" ? (StubEngine(window: 32768), 32768) : nil })
        let outcome = await host.selectModel(id: "qwen3-1.7b")
        XCTAssertEqual(outcome, .active(modelId: "qwen3-1.7b"))
        XCTAssertEqual(host.contextWindow, 32768)
        XCTAssertEqual(host.activeModelId, "qwen3-1.7b")
    }

    func test_selectModel_missing_keepsCurrentEngine() async {
        let host = EngineHost(
            initialEngine: StubEngine(window: 4096), initialModelId: "foundation_models_default",
            loader: { _ in nil })
        let outcome = await host.selectModel(id: "llama-3.2-1b")
        XCTAssertEqual(outcome, .missing(modelId: "llama-3.2-1b"))
        XCTAssertEqual(host.contextWindow, 4096)
        XCTAssertEqual(host.activeModelId, "foundation_models_default")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd b0tKit && swift test --filter EngineHostTests`
Expected: FAIL — `cannot find 'EngineHost' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import os
import b0tCore
import b0tBrain

/// A swappable `InferenceEngine`. The live managers hold this stable reference;
/// the inner engine swaps on model change so the managers never rebuild.
/// Approach A of `docs/specs/phase-2-stage-d-processor-inspector.md` §4.
///
/// A `final class` (not an actor) so `contextWindow`/`activeModelId` can be the
/// synchronous, `nonisolated` reads `InferenceEngine` requires. The lock guards
/// only reference reads/swaps; it is never held across `await`.
public final class EngineHost: InferenceEngine, @unchecked Sendable {
    /// Loads a concrete engine for a catalogue id, returning it with its context
    /// window, or `nil` when the model isn't present. Injected so this type stays
    /// testable without the llama binary; production passes a `ModelStore`-backed
    /// loader (see `makeProductionLoader`).
    public typealias Loader = @Sendable (_ modelId: String) async -> (any InferenceEngine, Int)?

    private let lock = OSAllocatedUnfairLock<State>(
        initialState: State(engine: nil, modelId: "", window: 4096))
    private struct State {
        var engine: (any InferenceEngine)?
        var modelId: String
        var window: Int
    }
    private let loader: Loader

    public init(initialEngine: any InferenceEngine, initialModelId: String, loader: @escaping Loader) {
        self.loader = loader
        lock.withLock {
            $0.engine = initialEngine
            $0.modelId = initialModelId
            $0.window = initialEngine.contextWindow
        }
    }

    public var contextWindow: Int { lock.withLock { $0.window } }
    public var activeModelId: String { lock.withLock { $0.modelId } }

    private var currentEngine: any InferenceEngine {
        lock.withLock { $0.engine } ?? FallbackEngine()
    }

    public func generate<Output: StructuredOutput>(
        context: AssembledContext, generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord]) {
        try await currentEngine.generate(context: context, generating: outputType)
    }

    /// Swap the live engine to `id`. Loads via the injected loader; on success
    /// swaps the inner engine + window; on absence returns `.missing` and leaves
    /// the current engine intact.
    public func selectModel(id: String) async -> ModelSelectionOutcome {
        guard let (engine, window) = await loader(id) else {
            return .missing(modelId: id)
        }
        lock.withLock {
            $0.engine = engine
            $0.modelId = id
            $0.window = window
        }
        return .active(modelId: id)
    }
}

/// Inert engine used only if the host is somehow queried before init populates it.
private struct FallbackEngine: InferenceEngine {
    var contextWindow: Int { 4096 }
    func generate<Output: StructuredOutput>(
        context: AssembledContext, generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord]) {
        throw InferenceEngineError.modelUnavailable
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd b0tKit && swift test --filter EngineHostTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tLlama/EngineHost.swift b0tKit/Tests/b0tLlamaTests/EngineHostTests.swift
git commit -m "feat(b0tLlama): EngineHost swappable engine wrapper (Stage D, approach A)"
```

---

### Task 4: `EngineHost.makeProductionLoader` — ModelStore-backed loader

A factory that builds the production `Loader`: for the FM catalogue entry, returns a `FoundationModelsEngine`; for a llama entry that's downloaded, loads via `ModelStore` and wraps in `LlamaEngine`; otherwise returns `nil`.

**Files:**
- Modify: `b0tKit/Sources/b0tLlama/EngineHost.swift`
- Test: `b0tKit/Tests/b0tLlamaTests/EngineHostLoaderTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import b0tCore
import b0tBrain
@testable import b0tLlama

final class EngineHostLoaderTests: XCTestCase {
    func test_loader_returnsNil_forUndownloadedLlamaModel() async {
        // A models directory with nothing in it → llama entries are absent.
        let emptyDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let downloads = ModelDownloadManager(modelsDirectory: emptyDir)
        let store = ModelStore(downloadManager: downloads)
        let loader = EngineHost.makeProductionLoader(store: store, downloads: downloads)
        let result = await loader("qwen3-1.7b")
        XCTAssertNil(result)
    }

    func test_loader_returnsNil_forUnknownModelId() async {
        let downloads = ModelDownloadManager(
            modelsDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let store = ModelStore(downloadManager: downloads)
        let loader = EngineHost.makeProductionLoader(store: store, downloads: downloads)
        let result = await loader("nope-not-real")
        XCTAssertNil(result)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd b0tKit && swift test --filter EngineHostLoaderTests`
Expected: FAIL — `type 'EngineHost' has no member 'makeProductionLoader'`.

- [ ] **Step 3: Write minimal implementation**

Append to `EngineHost.swift`:

```swift
extension EngineHost {
    /// Production loader: FM entry → `FoundationModelsEngine`; downloaded llama
    /// entry → `ModelStore`-loaded `LlamaEngine`; otherwise `nil`.
    public static func makeProductionLoader(
        store: ModelStore, downloads: ModelDownloadManager
    ) -> Loader {
        { modelId in
            guard let entry = InferenceModelCatalogue.entry(id: modelId) else { return nil }
            switch entry.engine {
            case .foundationModels:
                guard let fm = try? FoundationModelsEngine() else { return nil }
                return (fm, entry.contextWindow)
            case .llama:
                guard let file = entry.file else { return nil }
                let present = await downloads.isDownloaded(
                    filename: file, expectedSize: entry.sizeBytes)
                guard present else { return nil }
                let path = downloads.localURL(filename: file)
                guard let runtime = try? await store.load(
                    modelId: entry.id, path: path, contextLength: entry.contextWindow)
                else { return nil }
                return (LlamaEngine(runtimeReusing: runtime), entry.contextWindow)
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd b0tKit && swift test --filter EngineHostLoaderTests`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tLlama/EngineHost.swift b0tKit/Tests/b0tLlamaTests/EngineHostLoaderTests.swift
git commit -m "feat(b0tLlama): EngineHost.makeProductionLoader (FM/ModelStore-backed) (Stage D)"
```

---

## Slice 2 — Token metering (snapshot per turn)

### Task 5: `ConversationManager` emits `GenerationUsage`

`respondWithFallback` currently returns `(ConversationResponse, [ToolCallRecord])` and discards the assembled context. Thread the `TokenBudget` out and emit a `GenerationUsage` after a successful turn. Add a `modelIdProvider` (defaulted) so usage carries the active model id without coupling the manager to `EngineHost`.

**Files:**
- Modify: `b0tKit/Sources/b0tCore/ConversationManager.swift`
- Test: `b0tKit/Tests/b0tCoreTests/ConversationUsageTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import Combine
@testable import b0tCore
import b0tBrain

final class ConversationUsageTests: XCTestCase {
    func test_respond_emitsUsage_withInputFromBudgetAndOutputFromResponse() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bot = try Bot.empty(at: tmp)
        let store = BotStore()
        let stub = StubLanguageModelClient { _, outputType in
            ConversationResponse(text: "hello there friend")
        }
        let manager = ConversationManager(
            bot: bot, store: store, client: stub, modelIdProvider: { "qwen3-1.7b" })

        var received: GenerationUsage?
        let cancellable = manager.usageEvents.sink { received = $0 }
        defer { cancellable.cancel() }

        _ = try await manager.respond(to: "hi")

        let usage = try XCTUnwrap(received)
        XCTAssertEqual(usage.modelId, "qwen3-1.7b")
        XCTAssertGreaterThan(usage.tokensIn, 0)
        XCTAssertEqual(usage.tokensOut, TokenEstimator.estimate("hello there friend"))
        XCTAssertGreaterThan(usage.limit, 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd b0tKit && swift test --filter ConversationUsageTests`
Expected: FAIL — `extra argument 'modelIdProvider'` / `value of type 'ConversationManager' has no member 'usageEvents'`.

- [ ] **Step 3: Write minimal implementation**

In `ConversationManager.swift`:

1. Add the publisher + provider near `toolCallEvents`:

```swift
    /// Per-turn token-usage snapshot for the anatomy GUI (crown + Processor gauge).
    /// `nonisolated(unsafe)` for the same reason as `toolCallEvents`.
    nonisolated(unsafe) public let usageEvents = PassthroughSubject<GenerationUsage, Never>()

    private let modelIdProvider: @Sendable () -> String
```

2. Add `modelIdProvider` to `init` (defaulted) and store it:

```swift
    public init(
        bot: Bot,
        store: BotStore,
        client: any LanguageModelClient,
        clock: any Clock = SystemClock(),
        tools: [any Tool] = [],
        toolsRequirePermission: Bool = false,
        modelIdProvider: @escaping @Sendable () -> String = { "" }
    ) {
        self.modelIdProvider = modelIdProvider
        // ...existing assignments...
        self.assembler = ContextAssembler(
            bot: bot, store: store, tools: tools,
            toolsRequirePermission: toolsRequirePermission,
            contextWindowProvider: { [client] in client.contextWindow })
        // ...rest unchanged...
    }
```

(Replace the existing `contextWindow: client.contextWindow` argument with the provider form above.)

3. Change `respondWithFallback` to return the budget, and emit usage in `respond`:

```swift
    private func respondWithFallback(
        userPrompt: String, level: Int
    ) async throws -> (ConversationResponse, [ToolCallRecord], TokenBudget?) {
        let context = try await assembler.assemble(
            mode: .conversation(userPrompt: userPrompt), fallbackLevel: level)
        do {
            let (response, calls) = try await client.generate(
                context: context, generating: ConversationResponse.self)
            return (response, calls, context.budget)
        } catch LanguageModelClientError.exceededContextWindowSize {
            if level >= 3 {
                return (
                    ConversationResponse(
                        text: "oh — let me start fresh, I was getting muddled.",
                        mood: .thinking, memoryObservations: []),
                    [], nil)
            }
            return try await respondWithFallback(userPrompt: userPrompt, level: level + 1)
        }
    }
```

In `respond(to:)`, update the call site and emit usage just before returning the turn:

```swift
            let (response, toolCalls, budget) = try await respondWithFallback(
                userPrompt: userPrompt, level: 0)
            for record in toolCalls { toolCallEvents.send(record.toolName) }
            if let budget {
                usageEvents.send(GenerationUsage(
                    tokensIn: budget.estimated,
                    tokensOut: TokenEstimator.estimate(response.text),
                    limit: budget.limit,
                    modelId: modelIdProvider(),
                    breakdown: budget.breakdown))
            }
            let delta = try await executor.apply(response)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd b0tKit && swift test --filter ConversationUsageTests`
Expected: PASS.
Run: `cd b0tKit && swift test --filter b0tCoreTests`
Expected: PASS — no regressions.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tCore/ConversationManager.swift b0tKit/Tests/b0tCoreTests/ConversationUsageTests.swift
git commit -m "feat(b0tCore): ConversationManager emits per-turn GenerationUsage (Stage D)"
```

---

### Task 6: `HeartbeatManager` emits `GenerationUsage`

Mirror Task 5 for the heartbeat tick path.

**Files:**
- Modify: `b0tKit/Sources/b0tCore/HeartbeatManager.swift`
- Test: `b0tKit/Tests/b0tCoreTests/HeartbeatUsageTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import Combine
@testable import b0tCore
import b0tBrain

final class HeartbeatUsageTests: XCTestCase {
    func test_tick_emitsUsage_onDecidedBeat() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bot = try Bot.empty(at: tmp)
        let store = BotStore()
        let stub = StubLanguageModelClient { _, _ in
            TickDecision(observed: "o", considered: ["c"], decided: "pass", why: "w", acted: "noted")
        }
        let manager = HeartbeatManager(
            bot: bot, store: store, client: stub, modelIdProvider: { "llama-3.2-1b" })

        var received: GenerationUsage?
        let cancellable = manager.usageEvents.sink { received = $0 }
        defer { cancellable.cancel() }

        _ = try await manager.tick(trigger: .scheduled)

        let usage = try XCTUnwrap(received)
        XCTAssertEqual(usage.modelId, "llama-3.2-1b")
        XCTAssertGreaterThan(usage.tokensIn, 0)
    }
}
```

(If `.scheduled` is suppressed by quiet-hours in `Bot.empty`'s default schedule, use the trigger the existing heartbeat tests use for a guaranteed decided beat — check `HeartbeatManagerTests` for the canonical non-suppressed trigger and match it.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd b0tKit && swift test --filter HeartbeatUsageTests`
Expected: FAIL — no `usageEvents` / `modelIdProvider`.

- [ ] **Step 3: Write minimal implementation**

In `HeartbeatManager.swift`, mirror Task 5:

1. Add publisher + provider:

```swift
    nonisolated(unsafe) public let usageEvents = PassthroughSubject<GenerationUsage, Never>()
    private let modelIdProvider: @Sendable () -> String
```

2. Add `modelIdProvider: @escaping @Sendable () -> String = { "" }` to `init`, store it, and switch the assembler to the provider form: `contextWindowProvider: { [client] in client.contextWindow }`.

3. In `tick`, right after the successful `client.generate(...)` call that yields `(decision, toolCalls)` and where `context` is in scope, emit:

```swift
            usageEvents.send(GenerationUsage(
                tokensIn: context.budget.estimated,
                tokensOut: TokenEstimator.estimate(decision.acted),
                limit: context.budget.limit,
                modelId: modelIdProvider(),
                breakdown: context.budget.breakdown))
```

(Use `decision.acted` as the representative output text; it is the user-visible result of a beat.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd b0tKit && swift test --filter HeartbeatUsageTests`
Expected: PASS.
Run: `cd b0tKit && swift test --filter b0tCoreTests`
Expected: PASS — no regressions.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tCore/HeartbeatManager.swift b0tKit/Tests/b0tCoreTests/HeartbeatUsageTests.swift
git commit -m "feat(b0tCore): HeartbeatManager emits per-beat GenerationUsage (Stage D)"
```

---

## Slice 3 — Download seam + coordinator

### Task 7: `ModelDownloadServicing` protocol + `ModelDownloadCoordinator`

The protocol is the async backend seam (implemented in `b0tApp` over `ModelDownloadManager`). The coordinator is an `@Observable` class owning the UI-facing per-model state.

**Files:**
- Create: `b0tKit/Sources/b0tHome/Processor/ModelDownloadServicing.swift`
- Create: `b0tKit/Sources/b0tHome/Processor/ModelDownloadCoordinator.swift`
- Test: `b0tKit/Tests/b0tHomeTests/ModelDownloadCoordinatorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import b0tHome
import b0tBrain

@MainActor
final class ModelDownloadCoordinatorTests: XCTestCase {
    final class FakeService: ModelDownloadServicing, @unchecked Sendable {
        var downloaded: Set<String> = []
        var shouldFail = false
        func isDownloaded(modelId: String) async -> Bool { downloaded.contains(modelId) }
        func start(modelId: String, progress: @Sendable @escaping (Double) -> Void) async throws {
            progress(0.5)
            if shouldFail { throw ModelDownloadServiceError.failed(message: "boom") }
            progress(1.0)
            downloaded.insert(modelId)
        }
        func cancel(modelId: String) async {}
        func storage() async -> (freeBytes: Int, totalBytes: Int) { (5_000_000_000, 13_000_000_000) }
    }

    func test_refresh_marksDownloadedModels() async {
        let svc = FakeService(); svc.downloaded = ["qwen3-1.7b"]
        let coord = ModelDownloadCoordinator(service: svc)
        await coord.refresh()
        XCTAssertEqual(coord.state(for: "qwen3-1.7b"), .downloaded)
        XCTAssertEqual(coord.state(for: "llama-3.2-1b"), .notDownloaded)
    }

    func test_start_movesToDownloadedOnSuccess() async {
        let coord = ModelDownloadCoordinator(service: FakeService())
        await coord.start(modelId: "qwen3-1.7b")
        XCTAssertEqual(coord.state(for: "qwen3-1.7b"), .downloaded)
    }

    func test_start_movesToFailedOnError() async {
        let svc = FakeService(); svc.shouldFail = true
        let coord = ModelDownloadCoordinator(service: svc)
        await coord.start(modelId: "qwen3-1.7b")
        if case .failed = coord.state(for: "qwen3-1.7b") {} else { XCTFail("expected failed") }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd b0tKit && swift test --filter ModelDownloadCoordinatorTests`
Expected: FAIL — types not found.

- [ ] **Step 3: Write minimal implementation**

`ModelDownloadServicing.swift`:

```swift
import Foundation

/// Error surfaced by a download backend, already voice-guide-worded by the conformer.
public enum ModelDownloadServiceError: Error, Sendable, Equatable {
    case failed(message: String)
}

/// Async backend seam for model downloads. Implemented in `b0tApp` over
/// `b0tLlama.ModelDownloadManager`; kept abstract here so `b0tHome` (and its
/// host tests) never link the llama binary. Spec §6.
public protocol ModelDownloadServicing: AnyObject, Sendable {
    func isDownloaded(modelId: String) async -> Bool
    func start(modelId: String, progress: @Sendable @escaping (Double) -> Void) async throws
    func cancel(modelId: String) async
    func storage() async -> (freeBytes: Int, totalBytes: Int)
}
```

`ModelDownloadCoordinator.swift`:

```swift
import Foundation
import Observation
import b0tBrain

/// UI-facing download state for the Processor Directory tab. Owns the observable
/// per-model state; delegates the actual work to an injected `ModelDownloadServicing`.
/// One active download at a time (spec §6).
@MainActor
@Observable
public final class ModelDownloadCoordinator {
    public enum DownloadState: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
        case failed(message: String)
    }

    private let service: any ModelDownloadServicing
    private var states: [String: DownloadState] = [:]
    public private(set) var freeBytes: Int = 0
    public private(set) var totalBytes: Int = 0
    public private(set) var activeDownloadId: String?

    public init(service: any ModelDownloadServicing) {
        self.service = service
    }

    public func state(for modelId: String) -> DownloadState {
        states[modelId] ?? .notDownloaded
    }

    /// Populate state from disk for every downloadable catalogue model + storage.
    public func refresh() async {
        for entry in InferenceModelCatalogue.downloadable {
            let present = await service.isDownloaded(modelId: entry.id)
            states[entry.id] = present ? .downloaded : .notDownloaded
        }
        let s = await service.storage()
        freeBytes = s.freeBytes
        totalBytes = s.totalBytes
    }

    /// Start a download. No-op if another download is active (serial — spec §6).
    public func start(modelId: String) async {
        guard activeDownloadId == nil else { return }
        activeDownloadId = modelId
        states[modelId] = .downloading(progress: 0)
        do {
            try await service.start(modelId: modelId) { [weak self] p in
                Task { @MainActor in self?.states[modelId] = .downloading(progress: p) }
            }
            states[modelId] = .downloaded
        } catch let ModelDownloadServiceError.failed(message) {
            states[modelId] = .failed(message: message)
        } catch {
            states[modelId] = .failed(message: "Download didn’t finish. Try again.")
        }
        activeDownloadId = nil
        let s = await service.storage()
        freeBytes = s.freeBytes
        totalBytes = s.totalBytes
    }

    public func cancel(modelId: String) async {
        await service.cancel(modelId: modelId)
        states[modelId] = .notDownloaded
        if activeDownloadId == modelId { activeDownloadId = nil }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd b0tKit && swift test --filter ModelDownloadCoordinatorTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tHome/Processor/ b0tKit/Tests/b0tHomeTests/ModelDownloadCoordinatorTests.swift
git commit -m "feat(b0tHome): ModelDownloadServicing seam + ModelDownloadCoordinator (Stage D)"
```

---

## Slice 4 — Processor controller seam

### Task 8: `ProcessorControlling` protocol + `StubProcessorController` (test double)

The seam the Controls tab uses to read the current selection, switch models, and learn which models are present. Concrete production conformer (`AppProcessorController`) lands in Slice 6; here we define the protocol and a test double so the UI tasks can build against it.

**Files:**
- Create: `b0tKit/Sources/b0tHome/Processor/ProcessorControlling.swift`
- Test: `b0tKit/Tests/b0tHomeTests/ProcessorControllingTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import b0tHome
import b0tCore

@MainActor
final class ProcessorControllingTests: XCTestCase {
    func test_stub_reportsSelectionAndSwitch() async {
        let stub = StubProcessorController(
            engineLabel: "foundation models", modelId: "foundation_models_default",
            downloaded: ["qwen3-1.7b"])
        let sel = await stub.currentSelection()
        XCTAssertEqual(sel.modelId, "foundation_models_default")
        let outcome = await stub.selectModel(id: "qwen3-1.7b")
        XCTAssertEqual(outcome, .active(modelId: "qwen3-1.7b"))
        let missing = await stub.selectModel(id: "llama-3.2-1b")
        XCTAssertEqual(missing, .missing(modelId: "llama-3.2-1b"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd b0tKit && swift test --filter ProcessorControllingTests`
Expected: FAIL — types not found.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import b0tCore

/// The seam the Processor Controls tab binds to: read the current engine/model,
/// switch models (writing `processor.md` + re-resolving the live engine), and
/// learn which catalogue models are downloaded. Production conformer
/// (`AppProcessorController`) lives in `b0tApp`. Spec §4/§7.
public protocol ProcessorControlling: AnyObject, Sendable {
    func currentSelection() async -> (engineLabel: String, modelId: String)
    func selectModel(id: String) async -> ModelSelectionOutcome
    func downloadedModelIds() async -> Set<String>
}

/// Test/preview double.
public final class StubProcessorController: ProcessorControlling, @unchecked Sendable {
    private let engineLabel: String
    private let modelId: String
    private let downloaded: Set<String>
    public init(engineLabel: String, modelId: String, downloaded: Set<String>) {
        self.engineLabel = engineLabel
        self.modelId = modelId
        self.downloaded = downloaded
    }
    public func currentSelection() async -> (engineLabel: String, modelId: String) {
        (engineLabel, modelId)
    }
    public func selectModel(id: String) async -> ModelSelectionOutcome {
        downloaded.contains(id) || id == "foundation_models_default"
            ? .active(modelId: id) : .missing(modelId: id)
    }
    public func downloadedModelIds() async -> Set<String> { downloaded }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd b0tKit && swift test --filter ProcessorControllingTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tHome/Processor/ProcessorControlling.swift b0tKit/Tests/b0tHomeTests/ProcessorControllingTests.swift
git commit -m "feat(b0tHome): ProcessorControlling seam + stub (Stage D)"
```

---

## Slice 5 — Inspector UI + crown + state wiring

### Task 9: `AnatomyState` holds `latestUsage` + the two seams

**Files:**
- Modify: `b0tKit/Sources/b0tHome/AnatomyState.swift`
- Test: `b0tKit/Tests/b0tHomeTests/AnatomyStateUsageTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import b0tHome
@testable import b0tCore
import b0tBrain

@MainActor
final class AnatomyStateUsageTests: XCTestCase {
    func test_latestUsage_defaultsNil_andIsSettable() throws {
        let bot = try Bot.empty(at: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString))
        let state = AnatomyState(bot: bot, store: BotStore(), initialHeartBPM: 60)
        XCTAssertNil(state.latestUsage)
        state.latestUsage = GenerationUsage(
            tokensIn: 100, tokensOut: 20, limit: 4000, modelId: "x", breakdown: [:])
        XCTAssertEqual(state.latestUsage?.tokensIn, 100)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd b0tKit && swift test --filter AnatomyStateUsageTests`
Expected: FAIL — `value of type 'AnatomyState' has no member 'latestUsage'`.

- [ ] **Step 3: Write minimal implementation**

In `AnatomyState.swift`, add to the `@Observable` class:

```swift
    /// The most recent per-turn token usage (chat or heartbeat). Drives the crown
    /// meters + Processor Controls gauge. Set by `UsageListener`.
    public var latestUsage: GenerationUsage?

    /// Injected Stage-D seams (nil in previews/tests that don't exercise them).
    public var processorController: (any ProcessorControlling)?
    public var downloadCoordinator: ModelDownloadCoordinator?
```

(Add `import b0tCore` if not already present.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd b0tKit && swift test --filter AnatomyStateUsageTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tHome/AnatomyState.swift b0tKit/Tests/b0tHomeTests/AnatomyStateUsageTests.swift
git commit -m "feat(b0tHome): AnatomyState holds latestUsage + Stage-D seams"
```

---

### Task 10: `UsageListener` — subscribe `usageEvents` → `latestUsage`

Mirror the existing `ToolInvocationListener` pattern exactly.

**Files:**
- Create: `b0tKit/Sources/b0tHome/Internal/UsageListener.swift`
- Test: `b0tKit/Tests/b0tHomeTests/UsageListenerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import Combine
@testable import b0tHome
@testable import b0tCore
import b0tBrain

@MainActor
final class UsageListenerTests: XCTestCase {
    func test_listener_setsLatestUsageOnEvent() throws {
        let bot = try Bot.empty(at: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString))
        let state = AnatomyState(bot: bot, store: BotStore(), initialHeartBPM: 60)
        let subject = PassthroughSubject<GenerationUsage, Never>()
        let listener = UsageListener(state: state, source: subject.eraseToAnyPublisher())
        listener.start()
        subject.send(GenerationUsage(
            tokensIn: 200, tokensOut: 40, limit: 4000, modelId: "qwen3-1.7b", breakdown: [:]))
        XCTAssertEqual(state.latestUsage?.tokensOut, 40)
        listener.stop()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd b0tKit && swift test --filter UsageListenerTests`
Expected: FAIL — `cannot find 'UsageListener'`.

- [ ] **Step 3: Write minimal implementation**

```swift
@preconcurrency import Combine
import Foundation
import b0tCore

/// Bridges a manager's `usageEvents` to `AnatomyState.latestUsage`. Mirrors
/// `ToolInvocationListener`. PassthroughSubject delivers synchronously on the
/// calling queue; production wires this on MainActor.
@MainActor
public final class UsageListener {
    let state: AnatomyState
    let source: AnyPublisher<GenerationUsage, Never>
    private var cancellable: AnyCancellable?

    public init(state: AnatomyState, source: AnyPublisher<GenerationUsage, Never>) {
        self.state = state
        self.source = source
    }

    public func start() {
        cancellable = source.sink { [weak self] usage in
            MainActor.assumeIsolated { self?.state.latestUsage = usage }
        }
    }

    public func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd b0tKit && swift test --filter UsageListenerTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tHome/Internal/UsageListener.swift b0tKit/Tests/b0tHomeTests/UsageListenerTests.swift
git commit -m "feat(b0tHome): UsageListener bridges usageEvents to AnatomyState (Stage D)"
```

---

### Task 11: `ProcessorInspectionView` — model-notes helper (`.md` tab content)

Build the read-only model-notes string from a catalogue entry first (pure, testable), before the SwiftUI shell.

**Files:**
- Create: `b0tKit/Sources/b0tHome/Processor/ProcessorInspectionView.swift` (start with the helper)
- Test: `b0tKit/Tests/b0tHomeTests/ProcessorModelNotesTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import b0tHome
import b0tBrain

final class ProcessorModelNotesTests: XCTestCase {
    func test_notes_includeLicenseDisclosureContextAndSource() {
        let notes = ProcessorModelNotes.markdown(for: InferenceModelCatalogue.qwen3)
        XCTAssertTrue(notes.contains("Qwen3 1.7B"))
        XCTAssertTrue(notes.contains("Apache-2.0"))
        XCTAssertTrue(notes.contains("32768"))
        XCTAssertTrue(notes.contains("bartowski/Qwen_Qwen3-1.7B-GGUF"))
        XCTAssertTrue(notes.contains(InferenceModelCatalogue.qwen3.disclosure))
    }

    func test_notes_fmEntry_omitsDownloadSource() {
        let notes = ProcessorModelNotes.markdown(for: InferenceModelCatalogue.foundationModelsDefault)
        XCTAssertTrue(notes.contains("Apple Foundation Models"))
        XCTAssertFalse(notes.contains("resolve/"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd b0tKit && swift test --filter ProcessorModelNotesTests`
Expected: FAIL — `cannot find 'ProcessorModelNotes'`.

- [ ] **Step 3: Write minimal implementation**

In `ProcessorInspectionView.swift`:

```swift
import SwiftUI
import b0tBrain
import b0tCore

/// Builds the read-only `.md` tab content for a catalogue model (notes + source).
enum ProcessorModelNotes {
    static func markdown(for entry: InferenceModelEntry) -> String {
        var lines: [String] = ["# \(entry.displayName)", "", entry.disclosure, ""]
        lines.append("- license: \(entry.license)")
        lines.append("- context window: \(entry.contextWindow) tokens")
        if let quant = entry.quant { lines.append("- quantisation: \(quant)") }
        if let size = entry.sizeBytes {
            let gb = Double(size) / 1_000_000_000
            lines.append("- download size: \(String(format: "%.1f", gb)) GB")
        }
        if let repo = entry.repo, let sha = entry.pinnedSHA {
            lines.append("- source: \(repo) @ \(sha)")
        }
        return lines.joined(separator: "\n")
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd b0tKit && swift test --filter ProcessorModelNotesTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tHome/Processor/ProcessorInspectionView.swift b0tKit/Tests/b0tHomeTests/ProcessorModelNotesTests.swift
git commit -m "feat(b0tHome): ProcessorModelNotes builder for the .md tab (Stage D)"
```

---

### Task 12: `ProcessorInspectionView` — the 3-tab SwiftUI shell

Add the view to the file from Task 11. This is UI; verification is `RenderPreview` (per the Phase 4 convention — snapshot/visual sign-off is Hayden's, deferred). The view binds to `AnatomyState` (seams + `latestUsage`) and the `ModelDownloadCoordinator`. Temp slider omitted (spec §2). Match the ASCII layout in `anatomical-gui-and-inspector.md` §3.

**Files:**
- Modify: `b0tKit/Sources/b0tHome/Processor/ProcessorInspectionView.swift`

- [ ] **Step 1: Add the view (no test step — RenderPreview verification follows)**

```swift
public struct ProcessorInspectionView: View {
    @Bindable var state: AnatomyState
    @State private var tab: Tab = .controls
    @State private var selection: (engineLabel: String, modelId: String) = ("…", "")
    enum Tab: String, CaseIterable { case controls, directory, md = ".md" }

    public init(state: AnatomyState) { self.state = state }

    private var models: [InferenceModelEntry] { InferenceModelCatalogue.production }
    private var selectedIndex: Int {
        max(0, models.firstIndex { $0.id == selection.modelId } ?? 0)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            switch tab {
            case .controls: controls
            case .directory: directory
            case .md: notes
            }
        }
        .padding(12)
        .task { selection = await state.processorController?.currentSelection() ?? selection
                await state.downloadCoordinator?.refresh() }
        .tint(ProcessorPalette.yellow)
    }

    private var header: some View {
        HStack {
            Text("▦ processor").font(.system(.headline, design: .monospaced))
            Spacer()
            ForEach(Tab.allCases, id: \.self) { t in
                Button(t.rawValue) { tab = t }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(t == tab ? ProcessorPalette.yellow : .secondary)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("model").frame(width: 64, alignment: .leading)
                Button("◀") { cycle(-1) }
                Text(models[selectedIndex].displayName).frame(minWidth: 120)
                Button("▶") { cycle(1) }
            }
            Text("engine  \(selection.engineLabel)")
                .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            TokenGaugeView(usage: state.latestUsage)
        }.font(.system(.body, design: .monospaced))
    }

    private var directory: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(InferenceModelCatalogue.production) { entry in
                DownloadRowView(entry: entry, coordinator: state.downloadCoordinator)
            }
            if let c = state.downloadCoordinator {
                Text(storageLine(c)).font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var notes: some View {
        ScrollView {
            Text(ProcessorModelNotes.markdown(for: models[selectedIndex]))
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func storageLine(_ c: ModelDownloadCoordinator) -> String {
        let used = Double(c.totalBytes - c.freeBytes) / 1_000_000_000
        let total = Double(c.totalBytes) / 1_000_000_000
        return "── storage \(String(format: "%.1f", used)) / \(String(format: "%.0f", total)) GB ──"
    }

    private func cycle(_ delta: Int) {
        let next = (selectedIndex + delta + models.count) % models.count
        let id = models[next].id
        Task {
            let outcome = await state.processorController?.selectModel(id: id)
            selection = await state.processorController?.currentSelection() ?? selection
            if case .missing = outcome { tab = .directory }  // bounce (spec §2)
        }
    }
}

enum ProcessorPalette {
    static let yellow = Color(red: 0xEA/255, green: 0xFF/255, blue: 0x3D/255)
}
```

- [ ] **Step 2: Add subviews `TokenGaugeView` + `DownloadRowView`**

Append to the file:

```swift
struct TokenGaugeView: View {
    let usage: GenerationUsage?
    var body: some View {
        let u = usage
        VStack(alignment: .leading, spacing: 2) {
            bar(label: "in ", value: u?.tokensIn ?? 0, limit: u?.limit ?? 0)
            bar(label: "out", value: u?.tokensOut ?? 0, limit: u?.limit ?? 0)
            Text("\((u?.tokensIn ?? 0) + (u?.tokensOut ?? 0)) / \(u?.limit ?? 0) ctx")
                .font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
        }
    }
    private func bar(label: String, value: Int, limit: Int) -> some View {
        let frac = limit > 0 ? min(1.0, Double(value) / Double(limit)) : 0
        return HStack(spacing: 6) {
            Text(label).font(.system(.caption2, design: .monospaced))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.secondary.opacity(0.2))
                    Rectangle().fill(ProcessorPalette.yellow)
                        .frame(width: geo.size.width * frac)
                }
            }.frame(height: 8)
            Text("\(value)").font(.system(.caption2, design: .monospaced)).frame(width: 48, alignment: .trailing)
        }
    }
}

struct DownloadRowView: View {
    let entry: InferenceModelEntry
    let coordinator: ModelDownloadCoordinator?
    var body: some View {
        let st = coordinator?.state(for: entry.id) ?? .notDownloaded
        HStack(spacing: 8) {
            switch st {
            case .downloaded: Text("✓")
            case .downloading: Text("↓")
            default: Text("·").foregroundStyle(.secondary)
            }
            Text(entry.displayName).frame(maxWidth: .infinity, alignment: .leading)
            switch st {
            case .downloading(let p):
                ProgressView(value: p).frame(width: 80)
                Button("cancel") { Task { await coordinator?.cancel(modelId: entry.id) } }
            case .downloaded:
                if let s = entry.sizeBytes {
                    Text(String(format: "%.1f GB", Double(s)/1_000_000_000))
                        .font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                }
            default:
                if entry.engine == .foundationModels {
                    Text("(built-in)").font(.caption2).foregroundStyle(.secondary)
                } else {
                    Button("download") { Task { await coordinator?.start(modelId: entry.id) } }
                }
            }
        }.font(.system(.caption, design: .monospaced))
    }
}

#Preview("Processor — Controls") {
    let bot = try! Bot.empty(at: FileManager.default.temporaryDirectory.appendingPathComponent("preview"))
    let state = AnatomyState(bot: bot, store: BotStore(), initialHeartBPM: 60)
    state.processorController = StubProcessorController(
        engineLabel: "foundation models", modelId: "foundation_models_default", downloaded: ["qwen3-1.7b"])
    state.latestUsage = GenerationUsage(tokensIn: 1510, tokensOut: 220, limit: 4096, modelId: "qwen3-1.7b", breakdown: [:])
    return ProcessorInspectionView(state: state)
}
```

- [ ] **Step 3: Build the package**

Run: `cd b0tKit && swift build`
Expected: builds clean (no warnings).

- [ ] **Step 4: RenderPreview the view**

Use the `/preview ProcessorInspectionView` slash command (Apple MCP `RenderPreview`). Verify against `anatomical-gui-and-inspector.md` §3: yellow header, tab strip, model cycle, in/out gauge, directory rows + storage line. Visual sign-off is Hayden's; capture the render for review.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tHome/Processor/ProcessorInspectionView.swift
git commit -m "feat(b0tHome): ProcessorInspectionView 3-tab inspector (Stage D)"
```

---

### Task 13: `CrownTokenMetersView` + dispatch swap in `InspectionPanel`

**Files:**
- Create: `b0tKit/Sources/b0tHome/Processor/CrownTokenMetersView.swift`
- Modify: `b0tKit/Sources/b0tHome/InspectionPanel.swift:55-58`
- Delete: `b0tKit/Sources/b0tHome/Synthesised/ReasoningStateFile.swift`

- [ ] **Step 1: Add the crown view**

```swift
import SwiftUI
import b0tCore

/// The two small in/out token bars on the face crown — the glance view; the
/// Processor Controls tab is the drill-in. Spec §7.
public struct CrownTokenMetersView: View {
    let usage: GenerationUsage?
    public init(usage: GenerationUsage?) { self.usage = usage }
    public var body: some View {
        HStack(spacing: 4) {
            miniBar(value: usage?.tokensIn ?? 0, limit: usage?.limit ?? 0)
            miniBar(value: usage?.tokensOut ?? 0, limit: usage?.limit ?? 0)
        }.frame(width: 48, height: 6)
    }
    private func miniBar(value: Int, limit: Int) -> some View {
        let frac = limit > 0 ? min(1.0, Double(value) / Double(limit)) : 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(.secondary.opacity(0.25))
                Rectangle().fill(ProcessorPalette.yellow).frame(width: geo.size.width * frac)
            }
        }
    }
}
```

- [ ] **Step 2: Swap the dispatch**

In `InspectionPanel.swift`, replace the `.reasoning` case (currently building `OrganInspectionView(... file: ReasoningStateFile.make(state:))`):

```swift
        case .reasoning:
            ProcessorInspectionView(state: state)
```

Then delete `b0tKit/Sources/b0tHome/Synthesised/ReasoningStateFile.swift`.

- [ ] **Step 3: Build**

Run: `cd b0tKit && swift build`
Expected: builds clean. If anything else referenced `ReasoningStateFile`, update it (grep first: `grep -rn ReasoningStateFile b0tKit b0tApp`).

- [ ] **Step 4: Run the b0tHome suite**

Run: `cd b0tKit && swift test --filter b0tHomeTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tHome/Processor/CrownTokenMetersView.swift b0tKit/Sources/b0tHome/InspectionPanel.swift
git rm b0tKit/Sources/b0tHome/Synthesised/ReasoningStateFile.swift
git commit -m "feat(b0tHome): Processor inspector dispatch + crown meters; drop ReasoningStateFile (Stage D)"
```

---

## Slice 6 — App wiring + integration

### Task 14: `AppModelDownloadService` — `ModelDownloadServicing` over `ModelDownloadManager`

**Files:**
- Create: `b0tApp/Sources/App/Processor/AppModelDownloadService.swift`

This is app-target code (no SPM test target). Verify by build + the simulator smoke in Task 16.

- [ ] **Step 1: Implement**

```swift
import Foundation
import b0tBrain
import b0tHome
import b0tLlama

/// Production `ModelDownloadServicing` over `b0tLlama.ModelDownloadManager`.
/// One active download at a time is enforced by the coordinator (b0tHome).
final class AppModelDownloadService: ModelDownloadServicing, @unchecked Sendable {
    private let downloads: ModelDownloadManager
    private var tasks: [String: Task<Void, Error>] = [:]
    private let lock = NSLock()

    init(downloads: ModelDownloadManager) { self.downloads = downloads }

    func isDownloaded(modelId: String) async -> Bool {
        guard let entry = InferenceModelCatalogue.entry(id: modelId), let file = entry.file
        else { return false }
        return await downloads.isDownloaded(filename: file, expectedSize: entry.sizeBytes)
    }

    func start(modelId: String, progress: @Sendable @escaping (Double) -> Void) async throws {
        guard let entry = InferenceModelCatalogue.entry(id: modelId),
              let file = entry.file, let url = entry.sourceURL,
              let sha = entry.sha256, let size = entry.sizeBytes
        else { throw ModelDownloadServiceError.failed(message: "That model isn’t available to download.") }
        do {
            _ = try await downloads.download(
                from: url, filename: file, expectedSHA256: sha, expectedSize: size,
                progress: progress)
        } catch let ModelDownloadError.insufficientStorage(needed, available) {
            let gb = Double(needed - available) / 1_000_000_000
            throw ModelDownloadServiceError.failed(
                message: "Not enough room — free up about \(String(format: "%.1f", gb)) GB and try again.")
        } catch ModelDownloadError.checksumMismatch {
            throw ModelDownloadServiceError.failed(
                message: "The download didn’t verify. Try again.")
        } catch {
            throw ModelDownloadServiceError.failed(message: "The download didn’t finish. Try again.")
        }
    }

    func cancel(modelId: String) async {
        lock.lock(); let t = tasks[modelId]; tasks[modelId] = nil; lock.unlock()
        t?.cancel()
    }

    func storage() async -> (freeBytes: Int, totalBytes: Int) {
        let free = ModelDownloadManager.availableCapacityBytes(
            near: ModelDownloadManager.defaultModelsDirectory) ?? 0
        // Total is informational; approximate as free + already-used by models dir.
        return (free, max(free, 13_000_000_000))
    }
}
```

(Note: if `availableCapacityBytes` is not `public`, expose it `public static` in `ModelDownloadManager.swift` as a one-line visibility change in this task, with a doc-comment that the Stage-D storage line consumes it. Voice-check every thrown message against `docs/references/voice-and-copy-guide.md` — lowercase, plain, no exclamation beyond the curly apostrophe style already used.)

- [ ] **Step 2: Build the app**

Run the `/build` command (xcodebuild to a generic iOS simulator).
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add b0tApp/Sources/App/Processor/AppModelDownloadService.swift b0tKit/Sources/b0tLlama/ModelDownloadManager.swift
git commit -m "feat(b0tApp): AppModelDownloadService over ModelDownloadManager (Stage D)"
```

---

### Task 15: `AppProcessorController` + shared `EngineHost` wiring in `b0tApp`

Build one shared `EngineHost` and inject it everywhere: the heartbeat manager, the conversation manager, and `AppProcessorController`. `AppProcessorController.selectModel` writes `processor.md` then calls `engineHost.selectModel`.

**Files:**
- Create: `b0tApp/Sources/App/Processor/AppProcessorController.swift`
- Modify: `b0tApp/Sources/App/b0tApp.swift` (`resolveClient` + manager construction sites)

- [ ] **Step 1: Implement `AppProcessorController`**

```swift
import Foundation
import b0tBrain
import b0tCore
import b0tHome
import b0tLlama

/// Production `ProcessorControlling`: persists the selection to `processor.md`
/// and re-resolves the live `EngineHost`. Spec §4.
final class AppProcessorController: ProcessorControlling, @unchecked Sendable {
    private let bot: Bot
    private let store: BotStore
    private let host: EngineHost

    init(bot: Bot, store: BotStore, host: EngineHost) {
        self.bot = bot
        self.store = store
        self.host = host
    }

    func currentSelection() async -> (engineLabel: String, modelId: String) {
        let id = host.activeModelId
        let entry = InferenceModelCatalogue.entry(id: id)
        let label: String
        switch entry?.engine {
        case .foundationModels: label = "foundation models"
        case .llama: label = "llama · \(entry?.license ?? "")"
        case .none: label = "—"
        }
        return (label, id)
    }

    func selectModel(id: String) async -> ModelSelectionOutcome {
        // Persist to processor.md first (engine family + model id).
        if let entry = InferenceModelCatalogue.entry(id: id),
           let file = try? await store.read(bot.identity.processorURL) {
            let updated = file
                .settingFrontmatter("engine", to: .string(entry.engine.rawValue))
                .settingFrontmatter("model_id", to: .string(id))
            try? await store.write(updated)
        }
        return await host.selectModel(id: id)
    }

    func downloadedModelIds() async -> Set<String> {
        var ids: Set<String> = []
        let downloads = ModelDownloadManager()
        for entry in InferenceModelCatalogue.downloadable {
            if let file = entry.file,
               await downloads.isDownloaded(filename: file, expectedSize: entry.sizeBytes) {
                ids.insert(entry.id)
            }
        }
        return ids
    }
}
```

- [ ] **Step 2: Refactor `resolveClient` to return a shared `EngineHost`**

In `b0tApp.swift`, change `resolveClient` to build the initial engine (as today) but wrap it in an `EngineHost` with a production loader, and return the host. Keep the stub path. Store the host so the conversation manager, heartbeat manager, and `AppProcessorController` all share it. Concretely, replace the `switch decision { ... }` returns so each constructs the initial engine, then:

```swift
        let downloads = ModelDownloadManager()
        let modelStore = ModelStore(downloadManager: downloads)
        let initial: any LanguageModelClient
        let initialId: String
        switch decision {
        case .foundationModels:
            initial = fmOrStub(); initialId = "foundation_models_default"
        case .llama(let modelId, let contextLength):
            if let entry = InferenceModelCatalogue.entry(id: modelId), let file = entry.file,
               let engine = try? LlamaEngine(
                   modelPath: downloads.localURL(filename: file), contextLength: contextLength) {
                initial = engine; initialId = modelId
            } else { initial = fmOrStub(); initialId = "foundation_models_default" }
        case .llamaModelMissing:
            initial = fmOrStub(); initialId = "foundation_models_default"
        }
        let host = EngineHost(
            initialEngine: initial, initialModelId: initialId,
            loader: EngineHost.makeProductionLoader(store: modelStore, downloads: downloads))
        return host
```

Change `resolveClient`'s return type to `EngineHost` and have callers keep it (heartbeat). Pass `modelIdProvider: { [host] in host.activeModelId }` when constructing both `HeartbeatManager` and the production `ConversationManager` (audit ALL construction sites — Phase 3 smoke lesson #1: a constructor param added in one site but missed in another is a real bug; grep `HeartbeatManager(` and `ConversationManager(` across `b0tApp`).

- [ ] **Step 3: Inject seams into `AnatomyState`/`HomeView`**

Where the production `AnatomyState` is constructed and the chat `ConversationManager` is wired (the same place `toolCallEvents` → `ToolInvocationListener` is started — grep `ToolInvocationListener(`), also:
- set `state.processorController = AppProcessorController(bot:store:host:)`,
- set `state.downloadCoordinator = ModelDownloadCoordinator(service: AppModelDownloadService(downloads:))`,
- start a `UsageListener(state:source: conversationManager.usageEvents.eraseToAnyPublisher())`.

- [ ] **Step 4: Build the app**

Run `/build`.
Expected: builds clean, no warnings.

- [ ] **Step 5: Commit**

```bash
git add b0tApp/Sources/App/Processor/AppProcessorController.swift b0tApp/Sources/App/b0tApp.swift
git commit -m "feat(b0tApp): shared EngineHost + AppProcessorController wiring (Stage D)"
```

---

### Task 16: Integration — full-suite + simulator smoke + tracker update

**Files:**
- Modify: `docs/IMPLEMENTATION.md`

- [ ] **Step 1: Full package test suite**

Run: `cd b0tKit && swift test`
Expected: all green (the 331 baseline + the ~14 new Stage-D tests), 0 failures. Record the new total.

- [ ] **Step 2: App build**

Run `/build`.
Expected: clean.

- [ ] **Step 3: Simulator smoke (load-bearing — record results)**

On the iPhone 17 Pro simulator (per the Phase 3/4 smoke convention): launch, long-press home → tap the **Processor** organ. Verify:
1. Controls shows the current model + engine label; the in/out gauge updates after a chat turn.
2. Cycling to a not-downloaded model bounces to the Directory tab.
3. Directory shows ✓ for FM (built-in) + present models, a download button for absent ones, and the storage line.
4. The crown meters update after a chat turn.
(Real download exercise is bandwidth-dependent; the SmolLM2 test model is the smallest if a live download is run.)

- [ ] **Step 4: Update the tracker**

In `docs/IMPLEMENTATION.md`, mark Stage D's remote-friendly scope complete (Processor inspector + token metering, model switching, downloads), note the deferred items (live per-token metering, temperature plumbing) and that the device RAM/latency pass remains the only device-gated Phase-2 item. Update the test count.

- [ ] **Step 5: Commit**

```bash
git add docs/IMPLEMENTATION.md
git commit -m "docs: Stage D complete — Processor inspector + token metering (Phase 2)"
```

---

## Self-review notes (for the executor)

- **Spec coverage:** §4 engine swap → Tasks 2–4, 15. §5 token metering → Tasks 1, 5, 6, 9, 10. §6 downloads → Tasks 7, 14. §7 UI (Controls/Directory/.md/crown) → Tasks 11, 12, 13. §8 testing → embedded per task + Task 16. §9 out-of-scope respected (no live metering, no temp slider, no device pass).
- **Deferred-from-spec, intentionally:** temperature slider (spec §2/§9), live per-token metering (spec §9). Both are noted in the tracker update.
- **Type consistency:** `GenerationUsage`, `ModelSelectionOutcome` (b0tCore); `EngineHost.Loader`/`selectModel`/`makeProductionLoader` (b0tLlama); `ModelDownloadServicing`/`ModelDownloadCoordinator.DownloadState`/`ProcessorControlling` (b0tHome). `selectModel(id:)` name is identical across `EngineHost`, `ProcessorControlling`, and both stubs.
- **Watch items:** (a) confirm `Bot.empty`'s default schedule doesn't suppress the trigger used in Task 6 — match `HeartbeatManagerTests`' canonical decided-beat trigger; (b) `ModelDownloadManager.availableCapacityBytes` visibility (Task 14 may need a one-line `public`); (c) audit every `HeartbeatManager(`/`ConversationManager(` construction site when adding `modelIdProvider` (Phase 3 lesson).
