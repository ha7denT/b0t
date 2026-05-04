# b0tCore

The Foundation Models loop. Owns the lifecycle of `LanguageModelSession` instances, the `ContextAssembler`, and the `@Generable` decision types that the model returns.

## Public API contracts (as-built, Phase 2)

- `ConversationManager` — actor; `respond(to:) async throws -> ConversationResponse`. Orchestrates assemble → client → executor → journal. Retries on `.exceededContextWindowSize` via graduated fallback (private overload `respondWithFallback(userPrompt:level:)`).
- `HeartbeatManager` — actor; `tick(trigger:) async throws -> TickResult`, `scheduleNext() async throws`. DEBUG-only `startDebugTimer()` / `stopDebugTimer()`. (BGTaskScheduler `register(...)` happens in `b0tApp.@main.init()` because it must be called synchronously at app launch per Apple docs.)
- `LanguageModelClient` protocol; `LiveLanguageModelClient` (wraps `LanguageModelSession`) and `StubLanguageModelClient` (test seam).
- `ContextAssembler` — assembles `.conversation` and `.heartbeat` modes (public), plus an internal `assemble(mode:fallbackLevel:)` overload for graduated overflow recovery (levels 1/2/3 progressively trim content per spec §7.4). Token-budget logged in DEBUG via OSLog.
- `@Generable` types: `ConversationResponse`, `TickDecision`, `MemoryObservation`, `RelationshipNote`, `MoodTransition` (last two ship as types but aren't exercised in Phase 2).
- `Executor` — applies decisions to `BotStore` (memory observations to `memory/recent.md`, would-notify capture for Phase 4+ posting; respects `notification_budget_per_day` from `actions.md`).
- `JournalWriter` — OpenClaw-format appends in four variants (turn, heartbeat, suppressed, error).
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
