# b0tCore

The inference loop. Engine-agnostic as of ADR-0012: an `InferenceEngine` protocol with `FoundationModelsEngine` (Apple `LanguageModelSession`) as the only conformer today, and a llama.cpp engine arriving in Stage B. Owns the `ContextAssembler` and the decision types the model returns. Decision types are `@Generable` (FM path) **and** `Codable` (`StructuredOutput`, llama path).

## Public API contracts (as-built, Phase 3)

- `ConversationManager` — actor; `respond(to:) async throws -> ConversationTurn` (Phase 3 / T10 — see `ConversationTurn.swift`; carries the typed `ConversationResponse` plus `[ToolCallRecord]` observed during the turn). Orchestrates assemble → client → executor → journal. Retries on `.exceededContextWindowSize` via graduated fallback (private overload `respondWithFallback(userPrompt:level:)`).
- `HeartbeatManager` — actor; `tick(trigger:) async throws -> TickResult`, `scheduleNext() async throws`. DEBUG-only `startDebugTimer()` / `stopDebugTimer()`. (BGTaskScheduler `register(...)` happens in `b0tApp.@main.init()` because it must be called synchronously at app launch per Apple docs.) `TickResult.decided` carries `(decision: TickDecision, delta: StateDelta, toolCalls: [ToolCallRecord])` (Phase 3 / T12).
- `InferenceEngine` protocol (was `LanguageModelClient`, kept as a `typealias`); `generate<Output: StructuredOutput>(context:generating:)` returns `(Output, [ToolCallRecord])`. Conformers: `FoundationModelsEngine` (was `LiveLanguageModelClient`, aliased) wraps `LanguageModelSession`; `StubInferenceEngine` (was `StubLanguageModelClient`, aliased) is the test seam. `StructuredOutput` refines `Generable` and adds `Codable`; Stage B adds a `jsonSchema` requirement for schema→GBNF. Tool-descriptor decoupling is deferred to Stage B.
- `ContextAssembler` — assembles `.conversation` and `.heartbeat` modes (public), plus an internal `assemble(mode:fallbackLevel:)` overload for graduated overflow recovery (levels 1/2/3 progressively trim content per spec §7.4). `init` accepts `tools: [any Tool]` and `toolsRequirePermission: Bool` (Phase 3 / T25); when the flag is true the system prompt gains a permission-handling addendum instructing the model how to address `permissionDenied: true` tool results. Token-budget logged in DEBUG via OSLog.
- `@Generable` types: `ConversationResponse`, `TickDecision`, `MemoryObservation`, `RelationshipNote`, `MoodTransition` (last two ship as types but aren't exercised in Phase 2).
- `ConversationTurn` (Phase 3 / T10) — public `Sendable` struct wrapping a `ConversationResponse` plus `[ToolCallRecord]` observed during the turn.
- `Executor` — applies decisions to `BotStore` (memory observations to `memory/recent.md`, would-notify capture for Phase 4+ posting; respects `notification_budget_per_day` from `actions.md`).
- `JournalWriter` — OpenClaw-format appends in four variants (turn, heartbeat, suppressed, error). Both `appendConversationTurn` and `appendTick` render a `**tools_called:**` sub-section under the entry when `toolCalls` is non-empty (Phase 3 / T11–T12).
- `HeartbeatSchedule` — frontmatter parser for `schedule.md` (BPM, quiet hours via `ClockRange`, event triggers via `EventTriggerKind`).
- `MissedBeatDetector` — duration since last journal entry's timestamp.
- (no concrete `Tool`s ship from `b0tCore` as of Phase 3; the `TimeAwarenessTool` migrated to `b0tModules/TimeAwareness/` — see `b0tKit/Sources/b0tModules/CLAUDE.md`).
- `HeartbeatScheduler` protocol; `LiveBGTaskScheduler` (wraps `BGTaskScheduler.shared` on iOS only) and `FakeHeartbeatScheduler` (DEBUG-only, for unit tests).

## Patterns

- Every model call is a fresh `LanguageModelSession`. State persists in markdown files (`b0tBrain`), not in session memory.
- Token counts use `TokenEstimator` (4-chars-per-token heuristic). The graduated overflow fallback is the actual safety net.
- Conversation turns AND heartbeat ticks both append OpenClaw entries to `journal/YYYY-MM-DD.md`. Resolves PRD §3.2 vs design doc §5.4 ambiguity in PRD's favour. (Design doc §5.4 follow-up doc PR pending — see `docs/IMPLEMENTATION.md` Phase 2 notes.)
- BG-task arithmetic is unit-tested via `FakeHeartbeatScheduler`. The actual fact-of-firing is verified manually on real device.
- Bot name comes from `b0t_name` frontmatter on `identity/core.md` (via `BotFile.botName`), with `bot.rootURL.lastPathComponent` as fallback.
- Date/time formatting: UTC, POSIX locale, ISO8601 calendar — consistent across `JournalWriter`, `MissedBeatDetector`, and `DebugBrainView`.

## DEBUG launch args (recognised by `DebugBrainView` and `b0tApp`)

- `--use-stub-client` — force the stub client even when FM is available.
- `--debug-heartbeat-timer` — start an in-process `Task` loop that fires `tick(.scheduled)` at `bpm/4` (floored to 15s). Useful on simulator where `BGAppRefreshTask` is unreliable.

Both args are app-side only; production `@main` code path uses live clients and live scheduler.

## Manual smoke checklist

1. **Simulator with `--debug-heartbeat-timer`:** `DebugBrainView` chats via stub, ♥ button fires manual ticks, debug timer fires automatic ticks every 15s. Journal-tail pane grows.
2. **Real device with Apple Intelligence enabled:** live FM replies, ♥ tick fires successfully, BG task fires within OS-allowed window. LLDB trick to force-fire: `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.b0t.heartbeat"]`.

## Depends on

- `b0tBrain` (markdown reads/writes)
- `FoundationModels` (system, iOS 26)
- `BackgroundTasks` (system, iOS 26 — `LiveBGTaskScheduler` is iOS-only via `#if os(iOS)`)

## Does NOT depend on

- `b0tFace`, `b0tAudio`, `b0tDesign` (UI/output concerns belong in the app target or face/audio packages)
- `b0tModules` (Phase 3 — `b0tCore` exposes `AssembledContext.tools` as the integration point)

## Read first when working here

- `docs/specs/phase-2-foundation-models-loop.md` — design contract
- `docs/prd.md` §3.3, §3.4, §5.2, §5.6
- `docs/decisions/0001-on-device-only.md`, `0005-three-file-identity.md`
