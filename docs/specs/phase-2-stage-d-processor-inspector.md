# Phase 2 · Stage D — Processor inspector + token metering

**Status:** Design of record. Approved 2026-06-05 (brainstorm with Hayden).
**Phase:** 2 (inference-engine re-open) — the final Stage-D surface of `docs/specs/phase-2-inference-engine-abstraction.md`.
**Related:** [ADR-0012](../decisions/0012-inference-engine-agnostic.md) (engines), [ADR-0015](../decisions/0015-content-format-boundary-slot-assembly.md) (slots/token metering), [ADR-0016](../decisions/0016-aesthetic-reconciliation.md) (aesthetic), [ADR-0017](../decisions/0017-organ-ring-arrangement.md) (organ ring). Layout of record: `anatomical-gui-and-inspector.md` §3.

---

## 1. Purpose

Stage C (C1–C4) built the engine-selection data layer — `EngineSelector`, `InferenceModelCatalogue`, `ModelDownloadManager`, `ModelStore`, variable-window `TokenBudget` — but none of it is visible or interactive. The Processor organ today renders a dead placeholder (`ReasoningStateFile`, literal `—` dashes). Stage D makes the engine work the user can see and touch: a full interactive Processor inspector (model switching, downloads), per-turn token metering on the face crown and in Controls, and the supporting plumbing to swap the live engine mid-session.

This is the last remote-friendly Phase-2 pull. The only remaining Phase-2 item after Stage D is the device RAM/latency confirmation (out of scope here).

## 2. Scope decisions (settled in brainstorm)

| Decision | Choice |
|---|---|
| Ambition | **Full interactive inspector** — all 3 tabs live, model switching, downloads, crown meters. |
| Token feed | **Snapshot per turn** — no streaming; meters update once per completed turn. Live per-token ticking deferred to a polish pass (would reopen the Stage A protocol). |
| Model switch | **Immediate re-resolve + load** — write `processor.md`, re-run `EngineSelector`, load via `ModelStore` if downloaded; if missing, **bounce to the Directory tab and offer download**. |
| Temperature slider | **Omitted this pass** — temp is hardcoded (`0.7` llama; FM defaults) and not plumbed. Slider not rendered. Plumbing is a separate follow-up. |
| Engine-swap mechanism | **Approach A — `EngineHost` indirection** (see §4). |

## 3. Component map

**New types**
- `EngineHost` (b0tCore) — a swappable `InferenceEngine` wrapper holding the current concrete engine + the `ModelStore`. Managers hold this stable reference; the inner engine swaps invisibly.
- `GenerationUsage` (b0tCore) — per-turn token snapshot struct.
- `ConversationManager.usageEvents` / `HeartbeatManager.usageEvents` (b0tCore) — `PassthroughSubject<GenerationUsage, Never>`, mirroring the existing `toolCallEvents`.
- `ModelDownloadCoordinator` (b0tHome, `@Observable`) — binds the `ModelDownloadManager` actor to SwiftUI.
- `ProcessorInspectionView` (b0tHome) — the 3-tab inspector. Replaces `ReasoningStateFile`.

**Edited types**
- `ContextAssembler` (b0tCore) — read `contextWindow` live from the engine per-assembly instead of capturing it at init.
- `ConversationManager` + `HeartbeatManager` (b0tCore) — emit `GenerationUsage` after each turn/beat.
- `AnatomyState` (b0tHome) — subscribe to `usageEvents`, hold `latestUsage`; expose to crown view + inspector.
- Crown view (b0tHome / b0tFace) — render the two in/out bars from `latestUsage`.
- `b0tApp.resolveClient` (b0tApp) — construct managers with an `EngineHost` instead of a bare engine.

## 4. Engine swap — `EngineHost` (approach A)

`EngineHost` conforms to `InferenceEngine` and forwards `generate(context:generating:)` and `contextWindow` to a current inner engine it owns, alongside the `ModelStore`. Because the managers hold the host (whose identity never changes), swapping the inner engine is invisible to them.

`switch(toModelId:)` does:
1. Write `engine` + `model_id` to `identity/processor.md` (via `BotStore` + the immutable `BotFile.settingFrontmatter` pattern).
2. Re-run `EngineSelector.resolve(processorEngine:modelId:downloadedModelIds:)`.
3. Act on the result:
   - `.foundationModels` → swap inner engine to `FoundationModelsEngine`.
   - `.llama(modelId, contextLength)` → `ModelStore.load(modelId:path:contextLength:)`, build a `LlamaEngine` reusing the runtime, swap inner engine.
   - `.llamaModelMissing(modelId)` → leave inner engine unchanged; signal the UI to **bounce to the Directory tab** and surface the download affordance for that model.

**`ContextAssembler` change.** It currently captures `client.contextWindow` as an `Int` at init. Change it to read the window live per-assembly (hold the engine, or a `@Sendable () -> Int` accessor) so a window change on swap (e.g. qwen3 4096 → a model with a larger window) takes effect on the next assembly without rebuilding the manager.

**Concurrency.** `EngineHost` is an `actor` (it owns `ModelStore`, itself an actor, and mutable inner-engine state). `generate` and `contextWindow` reads are serialized through it. The window accessor passed to `ContextAssembler` bridges the actor boundary (async read, or a cached value updated on swap — implementation plan to choose the cleaner of the two given `ContextAssembler`'s call sites).

## 5. Token metering — snapshot per turn

```
struct GenerationUsage: Sendable, Equatable {
    let tokensIn: Int        // from the assembly's TokenBudget.estimated
    let tokensOut: Int       // TokenEstimator over the final response text
    let limit: Int           // TokenBudget.limit (active model context window)
    let modelId: String      // resolved model id at turn time
    let breakdown: [String: Int]  // TokenBudget.breakdown — per-slot/organ subtotals
}
```

`tokensIn`, `limit`, and `breakdown` come directly from the `TokenBudget` already produced during assembly. `tokensOut` is computed with the existing `TokenEstimator` over the final response string. Both managers `.send(usage)` on their `usageEvents` subject after a turn/beat completes (same `nonisolated(unsafe) public let` pattern as `toolCallEvents`).

`AnatomyState` subscribes to both managers' `usageEvents`, stores `latestUsage: GenerationUsage?`. The crown bars and the Controls token gauge both read `latestUsage` — single source of truth. Input + output share one ceiling (`limit`); the Controls drill-in renders the `breakdown` as per-organ subtotals (ADR-0015 slot attribution).

## 6. Download coordinator

`@Observable final class ModelDownloadCoordinator` (main-actor) wraps the `ModelDownloadManager` actor.

- Per-model `state: [modelId: DownloadState]` where `DownloadState = .notDownloaded | .downloading(progress: Double) | .downloaded | .failed(message: String)`.
- `start(entry:)` — kicks off `ModelDownloadManager.download(...)`; the `progress:` callback marshals to the main actor to update `state`. **One download at a time** (a queued second request waits or is disallowed — plan to pick; UI shows only one active bar in the v01 layout).
- `cancel(entry:)` — cancels the in-flight task; **keeps the `.part` file** (the manager already supports HTTP-Range resume, so a later `start` resumes).
- Storage line — `storageFreeBytes` / total, surfaced as `── storage X / Y GB free ──`. Driven by `ModelDownloadManager.availableCapacityBytes`.
- On completion, checksum + size are verified by the manager; a mismatch surfaces as `.failed` with a voice-guide error string.

All user-facing strings (errors, the storage line, the catalogue disclosure copy) run through `docs/references/voice-and-copy-guide.md`.

## 7. Processor inspector UI

Yellow-header 3-tab inspector raised into the lower half on Processor-organ tap. Tabs render only if declared. Layout of record: `anatomical-gui-and-inspector.md` §3.

**Controls**
- Model cycle `◀ qwen3-1.7b ▶` over the catalogue's downloadable entries + Foundation Models; drives `EngineHost.switch(toModelId:)`.
- Engine label: `llama · Built with —` (Llama attribution) or `foundation models`.
- In/out token meters (Stat Bar sprite) sharing one ceiling `/ N ctx`, from `latestUsage`; the per-organ `breakdown` is the drill-in.
- **No temp slider this pass.**

**Directory** (download manager)
- One row per catalogue model: `✓` downloaded (with size) / `↓` with progress bar + `[cancel]` while downloading / download affordance when absent.
- Foundation Models row shown as `✓ (built-in)`.
- `── storage X / Y GB free ──` footer.

**.md**
- Synthesized read-only model notes built from the catalogue entry: displayName, license, disclosure copy, context window, size, source repo + pinned SHA.
- Plus the read-only chat template (ADR-0015, advanced).

**Crown** (on the face, not the inspector)
- The two small in/out bars driven by `latestUsage` — the glance view; the Controls tab is the drill-in.

**Assets.** Per `anatomical-gui-and-inspector.md` §3 mapping table: `1bit_UI_Pixel_Pack` panel (9-slice, yellow-tinted), Stat Bar for meters + download progress, switches/value-control/arrows for cycle, scrollbar thumb for the directory list. Runtime mask-tinted yellow (processor semantic colour).

## 8. Testing

- **`EngineHost` swap** — FM↔llama↔missing transitions with stub engines + a fake `ModelStore`; assert inner-engine identity, `processor.md` writes, and the missing→Directory signal. Pure, host-testable.
- **`ContextAssembler` live window** — swap the window source, assert the budget limit follows on the next assembly.
- **`GenerationUsage` emission** — drive both managers with a stub engine; assert the published snapshot matches the `TokenBudget` + estimated output.
- **`ModelDownloadCoordinator` state machine** — fake manager exercising progress / cancel / resume / insufficient-storage / checksum-mismatch.
- **`ProcessorInspectionView`** — `RenderPreview` / snapshot for the three tabs + the crown bars; verify yellow tint and Stat-Bar rendering.

## 9. Out of scope

- **Live per-token metering** — needs an `onProgress(tokensGenerated:)` extension to the `InferenceEngine` protocol (Stage A); deferred to a polish pass.
- **Temperature plumbing** — separate follow-up (read `processor.md` `temperature` → llama sampler + FM `GenerationOptions`).
- **Device RAM/latency confirmation** — the iPhone 13 Pro pass (spec §6b of the Q6 validation note); device-gated.
- **Home-screen focus/chat states** and the **first-run view** — not yet designed (`anatomical-gui-and-inspector.md` §5).
- `DebugBrainView` resolver parity — small follow-up; align the debug path with `EngineHost`/`resolveClient`.
