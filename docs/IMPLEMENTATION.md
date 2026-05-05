# Implementation tracker

A living document. Updated at the end of each phase, or when a blocker appears.

## Current state

- **Phase:** 4 — Anatomical GUI (static face)
- **Status:** implementing — Slice 0 complete (`c07fbec`); Slice 1 ready (b0tDesign palettes & shaders)
- **Spec:** [phase-4-anatomical-gui](specs/phase-4-anatomical-gui.md)
- **Plan:** [phase-4-anatomical-gui](plans/phase-4-anatomical-gui.md)

## Phase ledger

| # | Phase | Plan | Status |
|---|---|---|---|
| 0 | Project setup | [phase-0](plans/phase-0-project-setup.md) | complete (2026-04-30) |
| 1 | Markdown brain (no LLM) | [phase-1](plans/phase-1-markdown-brain.md) | complete (2026-05-01) |
| 2 | Foundation Models loop | [phase-2](plans/phase-2-foundation-models-loop.md) | complete (2026-05-04) |
| 3 | Module bridges + Tools | [phase-3](plans/phase-3-modules-and-tools.md) | complete (2026-05-05) |
| 4 | Anatomical GUI (static face) | [phase-4](plans/phase-4-anatomical-gui.md) | specced |
| 5 | Onboarding sequence | — | not started |
| 6 | Face rig + Parts library + Face Creator | — | not started |
| 7 | Multi-b0t and Gallery | — | not started |
| 8 | Audio (TTS + effects) | — | not started |
| 9 | IAP and trial | — | not started |
| 10 | Polish and ship | — | not started |

## Open questions on the boil

(Questions surfaced here are alive — once answered, they're closed in the relevant plan or ADR.)

- Hilfer's three Part PNGs + 9 organ icons + 4 module sub-icons + 1 file icon — Jamee committed to deliver. Implementation can scaffold against placeholders; visual sign-off blocks Phase 4 close-out.

## Specs in flight

- [phase-4-anatomical-gui](specs/phase-4-anatomical-gui.md) — settled 2026-05-05; produces ADR-0010, ADR-0011, face-roster.md, manufacturers.json

## Notes from Phase 0

- Plan deviation: Xcode project scaffolded via `xcodegen` (YAML source of truth) rather than manual Xcode IDE creation. Same outcome, more agent-friendly. `b0t.xcodeproj` is committed for IDE convenience and is regenerable from `project.yml`.
- Font choice changed: Berkeley Mono → IoskeleyMono NL (open-source, OFL). PRD §12 Q6 and design doc §3.4 updated.
- The `default-bot/` directory at the repo root is bundled into the iOS app via an xcodegen folder reference (`type: folder, buildPhase: resources`). Files added to `default-bot/` on disk land in the bundle on next build with no further action.
- swift-format pre-commit hook lives at `.git/hooks/pre-commit` (not committed; git hooks live outside the working tree). A future onboarding script for new contributors is out of scope.
- CI runner is `macos-latest` (not `macos-15` as the plan originally specified). The plan's own contingency note anticipated this — Xcode 26 isn't reliably on `macos-15` images, and `macos-latest` keeps us on whatever GitHub currently ships with. Re-evaluate if CI starts hitting toolchain mismatches.

## Notes from Phase 1

- Spec at `docs/specs/phase-1-markdown-brain.md` settled seven design questions during brainstorming (scope, lossless strategy, API typing, concurrency, malformed-input policy, cache invalidation, provisioning). Plan at `docs/plans/phase-1-markdown-brain.md` decomposed the spec into 22 TDD-shaped tasks.
- Final shape: 78 tests passing across the b0tKit package suite, including a production-default-bot integration test that loads every shipped file and asserts `parseError == nil`.
- Yams 5.x added as the only new SPM dependency. Privacy-audit clean (no network calls).
- Several mid-implementation deviations and fix-up commits captured along the way: `MarkdownSplitter` EOF-closer crash fix, `FrontmatterParser` zip-misalignment guard, `BotFile` mutation correctness (leading YAML indicators, NaN/Infinity, no-op short-circuit), `BotFile.appendingProseSection` trailing-newline normalisation, `BotStore.write` real failure-injection test, `Bot.swift` case-insensitive `.md` filter, and a spec/code reconciliation on `BotStore.write`'s signature.
- Manual simulator launch (the plan's Step 22.4 / "see 'active: b0t-01' on screen") deferred to Jamee — agent harness can't drive the simulator UI deterministically.

## Notes from Phase 2

- Spec at `docs/specs/phase-2-foundation-models-loop.md` settled five design questions during brainstorming on 2026-05-01 (scope shape, acceptance demo bar, model-layer testability, demo surface, conversation-turns-also-journal). Plan at `docs/plans/phase-2-foundation-models-loop.md` decomposed the spec into 40 walking-skeleton tasks across 10 slices. Implemented 2026-05-01 to 2026-05-04.
- Final shape: `b0tCore` module with ~25 public types, 145 SPM tests passing, 2 gated live-FM integration tests against the production `default-bot/`.
- No new third-party SPM dependencies. `FoundationModels` and `BackgroundTasks` are system-provided (iOS 26 / macOS 26).
- Privacy audit: confirmed zero new network calls. `LanguageModelSession` is on-device per Apple's design; `BGTaskScheduler` is a system service. No telemetry, no analytics. Privacy posture intact.
- Decision (i) — conversation turns also produce OpenClaw journal entries — resolves a PRD §3.2 vs design doc §5.4 ambiguity in PRD's favour. Follow-up doc PR applied 2026-05-04: design doc §5.4 updated to read "Each heartbeat or conversation turn appends an entry…".
- Phase 1 note about "first spec planned: `context-assembler.md` during Phase 2 prep" is closed — subsumed by the Phase 2 spec.
- Mid-phase plan-vs-SDK adaptations made (and well-documented in commit bodies):
  - `@Generable(representNilExplicitlyInGeneratedContent: true)` doesn't exist in Xcode 26.2's SDK — used plain `@Generable` (handles `Optional` natively).
  - `Tool` protocol's `name`/`description` are instance properties, not static (Task 32).
  - `BGTaskScheduler` is `API_UNAVAILABLE(macos)` — needed `#if canImport(BackgroundTasks) && os(iOS)` guard (Task 28).
  - `INFOPLIST_KEY_BGTaskSchedulerPermittedIdentifiers` doesn't propagate via xcodegen 2.44.1 — committed a physical `b0tApp/Info.plist` instead (Task 30).
  - `ClosedRange<ClockTime>` runtime-rejects overnight ranges (22:00...06:30) — introduced custom `ClockRange` struct (Task 22).
  - `AssemblyMode.fallback` was dropped from the public enum during the Slice-1+2 design fix (commit `856448b`); fallback is an internal `assemble(mode:fallbackLevel:)` overload (Task 36).
- `Package.swift` adds `.macOS("26.0")` alongside `.iOS("26.0")` — required so SPM `swift build`/`swift test` on the macOS host can resolve `FoundationModels` (which is macOS 26+ only, not back-deployable). Phase 4 may revisit if a separate macOS target is wanted.
- The canonical-bot test fixture grew during Phase 2 to mirror more of production `default-bot/`'s shape: `actions.md` body filled in (was stub), `schedule.md` gained `event_triggers` and `mutable` fields, `identity/core.md` `name:` key renamed to `b0t_name:` to match production.
- Docs to refresh in a follow-up sweep (post-phase-close): doc-comment "Slice N (forthcoming)" references in several files now describe completed work in past tense; spec §5.7 still uses `TimeOfDay` for the HH:MM type which got renamed to `ClockTime`.

## Notes from Phase 3

- Spec at `docs/specs/phase-3-modules-and-tools.md` settled eight design questions during brainstorming on 2026-05-04 (scope shape, MCP-as-architecture-only, demo bar, Module-vs-ToolHandle, permission-denial flow, tool surface per module, lenient registry, registry seam location). Plan at `docs/plans/phase-3-modules-and-tools.md` decomposed the spec into 32 tasks across 7 walking-skeleton slices. Implemented 2026-05-04 to 2026-05-05.
- Final shape: `b0tModules` package with 4 Modules (TimeAwareness, Calendar, Reminders, Health-iOS-only), 5 public Tools, ~196 SPM tests passing on macOS host, 4 gated live tests for iOS simulator (`LIVE_TESTS=1`). `b0tCore` ships zero concrete `Tool`s — all migrated to `b0tModules`.
- No new third-party SPM dependencies. `EventKit`, `HealthKit`, `FoundationModels` all system-provided.
- Privacy audit: confirmed zero new network calls in `b0tModules`. Both `EventKit` and `HealthKit` are local-only system APIs. No telemetry, no third-party SDKs that phone home. Privacy posture intact.
- Decision: `Module` returns `[any Tool]` directly rather than the PRD §5.3 sketch's `[ToolHandle]` indirection. ADR-0009 records the rationale (FM `Tool` already encodes the MCP shape via `@Generable`; a wrapper would re-serialise without information). PRD §5.3 is now treated as historical sketch superseded by the as-built code + ADR-0009.
- Mid-phase plan-vs-SDK adaptations made:
  - `EKEventStore` is non-`Sendable` in Swift 6 strict concurrency — used `@preconcurrency import EventKit` and `nonisolated(unsafe)` on the stored property in `LiveEventKitStore` (Task 14). Same pattern for `HKHealthStore` in `LiveHealthStore` (Task 22).
  - `EKEventStore.fetchReminders(matching:completion:)` is callback-based — bridged to async via `withCheckedContinuation` plus a `SendableRemindersBox: @unchecked Sendable` wrapper (Task 18) to satisfy the strict-concurrency boundary.
  - `package init` (not `public`) on `Module`/`Tool` initialisers that accept a `PermissionGate` — Swift forbids exposing a package-scoped type in a public signature. The structs themselves remain public; outside callers get tools via the `ModuleRegistry` pipeline (Tasks 16, 17, 19, 20, 21, 23, 24).
  - `extractToolCallRecords(from: Transcript)` initially keyed by `toolName` — caught in T9 quality review as a latent bug (same tool called twice would silently overwrite outputs). Fixed to id-based pairing using `Transcript.ToolCall.id` / `Transcript.ToolOutput.id` (commit `cae08d9`). Also switched `argumentsSummary` from `String(describing:)` to `GeneratedContent.jsonString` for compact human-readable output.
  - `BotFile.enabled` and `BotFile.moduleID` accessors in `KnownFiles.swift` already encapsulated the frontmatter pattern-matching the registry needed — caught in T4 quality review and refactored to use them rather than duplicating logic (commit `b785e49`).
  - `default-bot/modules/time-awareness.md` had `module_id: time_awareness` (underscore) but the registry factory key is `"time-awareness"` (hyphen) — caught by T28's production-default-bot integration test (commit `7b6bda5`). Markdown corrected to match.
- T17 implementer chose to collapse the plan's `Health/` and `HealthKit/` subdirectories into a single `HealthKit/` directory — `HealthModule` and `HealthStepsTodayTool` live alongside `HealthStore`. Minor structural deviation, no functional impact.
- T26 (app-layer wiring) updated `ConversationManager.init` and `HeartbeatManager.init` to accept `tools: [any Tool] = []` and `toolsRequirePermission: Bool = false` (defaulted, backward-compatible). `DebugBrainView.initializeManager` now calls `ModuleRegistry.loadModules(for: bot)` and threads the result into both managers. The `try? ... ?? []` pattern is intentional fault-tolerance — a registry-load failure shouldn't block app startup.
- T27 added `NSCalendarsUsageDescription`, `NSRemindersFullAccessUsageDescription`, `NSHealthShareUsageDescription` to `b0tApp/Info.plist` directly (not via `project.yml` `INFOPLIST_KEY_*`). Phase 2 Task 30 had already documented xcodegen 2.44.1 dropping these keys — same pattern reused.
- The `JournalWriter.swift:217` (now `:235`-ish) "Conditional cast from any Error to any CustomStringConvertible always succeeds" warning is pre-existing Phase 2 lint, surfaced by SourceKit when nearby files were edited. Out of Phase 3 scope; flagged for a future cleanup sweep.
- Manual smoke checklist (real-device or simulator with Apple Intelligence enabled) deferred to Jamee — agent harness can't drive the simulator UI deterministically. Spec §10 acceptance criteria #1–#6 (in-conversation calendar/reminders/health flow) are the load-bearing live verification.

### Manual smoke verification (2026-05-05)

Jamee smoke-tested on iPhone 17 Pro simulator (iOS 26.3). End-to-end behaviour confirmed:

- `[b0t] loaded 3 modules: ["calendar", "reminders", "time-awareness"]` at startup.
- Tool-call rows render inline in `DebugBrainView` (T13): `→ calendar.upcoming_events({})` followed by `← {events: [...], permissionDenied: false}`.
- `**tools_called:**` sub-section appears in the journal entry for turns that invoke tools (T11).
- The `Executor` records calendar memory observations: `(high) calendar: Upcoming event 'GRONK' scheduled` → `state_delta: memory/recent.md`.
- Permission flow works: first calendar question pops the system permission sheet; granting lets the tool query EventKit; the b0t reads real event titles and times.
- The b0t stays in voice for off-topic prompts (PRD voice-and-copy intact).

Five real bugs surfaced and were fixed during the smoke pass — each had passing unit tests at the time, hence the lessons:

1. **Production heartbeat path missed `tools` wiring** (`b0tApp.initializeHeartbeat`). T26 only updated `DebugBrainView`; the BG-task-fired manager constructed `HeartbeatManager(bot:store:client:)` with no tools. Fixed in commit `98d8bf9`. Lesson: when adding a parameter to a constructor used in multiple call sites, audit every site.
2. **`BotProvisioner` staleness**: only copies the bundled `default-bot/` into Documents on first launch (`if !fm.fileExists(target)`). Pre-Phase-3 installs in the simulator had no `modules/` directory, so `ModuleRegistry.loadModules` returned `[]` silently. Fix: wipe the simulator's app data so BotProvisioner re-copies. Underlying issue documented as a follow-up; not fixed in Phase 3.
3. **`NSPredicate(value: true)` rejected by EventKit**: `EKEventStore.eventsMatchingPredicate:` throws `NSInvalidArgumentException` on any predicate not built via its own factory. The `FakeEventKitStore` ignored predicates entirely, masking the live constraint. Fixed by extending `EventKitStore` with `predicateForEvents(withStart:end:calendars:)` (commit `c5b6c78`). Lesson: fakes that ignore inputs hide live-API contracts.
4. **In-memory `startDate >= now` filter excluded ongoing events** (e.g. a meeting that started before `now` but hasn't ended). EventKit's predicate uses overlap semantics; our filter contradicted it. Fixed to `endDate >= now && startDate <= end` (commit `f037b69`).
5. **UTC ISO timestamps misled the model**: tool serialised `EKEvent.startDate` as `"2026-05-05T07:00:00Z"`. The model read the digits literally and reported "7am" for an event scheduled at 5pm AEST. Fixed by switching the formatter to `TimeZone.current` with the offset suffix preserved (`"2026-05-05T17:00:00+10:00"`) — same instant, the wall-clock numerals match what the user sees in their Calendar app (commit `2078b2b`). Lesson: ISO-8601 with a `Z` suffix is timezone-erasing for any consumer that doesn't parse the offset.

### Phase 3 follow-ups (out of scope; tracked for Phase 3.5 or later)

- **`reminders.create` not always invoked**: when asked "remind me at 4 about this," the model said "I will remind you at 4 pm" without calling the tool. Tools are wired correctly; the model needs a system-prompt nudge ("if asked to do X, actually call the tool — don't just say you will"). Either tighten the permission addendum or add a separate "actually invoke tools when asked" instruction in `ContextAssembler`.
- **Calendar "today" semantic**: `calendar.upcoming_events` is forward-looking from `now`. Asking "what was on my calendar this morning?" returns nothing because morning events have already ended. Either add a separate `calendar.events_today` tool with a `[startOfDay, endOfDay]` window, or extend the existing tool with a `lookbackHours` arg.
- **`BotProvisioner` only copies once**: subsequent updates to the bundled `default-bot/` don't propagate to existing installs. A "sync new files from bundle on launch" pass would fix this, but must be careful not to overwrite user-edited markdown. Out of Phase 3 scope; will become more pressing if Phase 4+ ships new module files.
- **Pre-existing lint warning** at `JournalWriter.swift:235`: `error as? CustomStringConvertible` always succeeds. Trivial cleanup; not Phase 3 scope.

### Documentation drift to refresh (post-phase-close)

- PRD §1.5 `b0tModules/` comment reads "EventKit/Mail/HealthKit/Location bridges" — Phase 3 ships EventKit (calendar+reminders) + HealthKit only; Mail/Location/Notes/Weather deferred to Phase 3.5 or later.
- PRD §5.3 sketches `Module` with `toolHandles` — superseded by ADR-0009; the PRD section can be marked historical or amended.
