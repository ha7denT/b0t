# Implementation tracker

A living document. Updated at the end of each phase, or when a blocker appears.

## Current state

- **Phase:** 5 deferred 2026-05-06; **Phase 2 re-opened 2026-05-29** (engine
  abstraction). Next phase to be selected after the Phase 2 re-open is planned.
- **Status:** Phase 5 paused mid-brainstorm, deferred until the features it
  showcases are built. Roughly a third of the 24 onboarding beats reference
  modules that don't yet exist (mail, location, notes, weather) or features
  in later phases (face creator → Phase 6, multi-b0t → now v2). Shipping
  onboarding now would have the b0t introduce features it can't actually
  perform — a credibility problem on day one. The brainstorm settled
  enough to make resumption cheap (see "Specs in flight" below).

### Amendment 2026-05-29 (recorded 2026-05-30)

`docs/b0t-amendment-2026-05-29.md` reframes b0t as **tool-first**, makes
inference **engine-agnostic** (Foundation Models default-when-available;
llama.cpp-backed downloadable open-weight models otherwise, switchable
everywhere — [ADR-0012](decisions/0012-inference-engine-agnostic.md)), and
**contracts v1 to a single non-modular b0t** (modular face, multi-b0t/Gallery,
and the unlock economy → v2 — [ADR-0013](decisions/0013-v1-single-non-modular-bot.md)).
Speech is signalled by an illuminated grille, no moving jaw
([ADR-0014](decisions/0014-speech-via-illuminated-grille.md)); prompts use a
content/format boundary + slot-based assembly
([ADR-0015](decisions/0015-content-format-boundary-slot-assembly.md)); the
aesthetic goes LCD-forward with a yellow/aqua/pink semantic palette
("never blue" overridden — ADR-0016, **pending** Jamee's UI designs).
Impact map: `docs/plans/amendment-2026-05-29-interpretation.md`.

- **§14 resolved 2026-05-30:** Q3 (palette override), Q4 (single b0t), Q5
  (FM default-but-switchable everywhere; llama.cpp downloadable path), Q6
  (FM + 3 downloadable models; disclosures in the Processor inspector — exact
  trio + quant levels pending on-device validation), Q7 (minimal TTS), Q9
  (iOS 26 + 6GB-RAM floor).
- **§14 Q1/Q2 resolved 2026-05-30** against Jamee's home-screen mockup
  (`assets/ref/`): painterly face (Q1), emissive aqua eye-screen kept (Q2).
  [ADR-0016](decisions/0016-aesthetic-reconciliation.md) authored; design doc
  §3.3/§3.5/§3.6 finalized. All §14 aesthetic items now closed. (Q8 trial
  length remains a pre-launch call.)
- **Layout (captured 2026-05-31):** organ ring reorganized — left/right
  world-vs-mind columns; processor crown (Reasoning renamed); journal a new
  10th organ — recorded in [ADR-0017](decisions/0017-organ-ring-arrangement.md).
  Home layout, face/grille, inspector (3-tab strip; enable/disable in Controls),
  and the v01 organ→icon mapping captured in
  `docs/specs/anatomical-gui-and-inspector.md`. Implementation (the GUI-revision
  "Stage D") is gated on Stage C. Not yet designed: focus/chat states, first-run. **Face animation resolved 2026-05-30:** Gamelabs-generated
  animation sprite-sheet; the grille is the sole v1 emissive element (a transparent
  cut-out in the face sprite lit by an emissive shape behind it in z-space;
  head rotation ≤ a few degrees keeps it leak-free); eye-screen baked, no v1 emissive
  (fancy eye-screen → v2). See ADR-0014/0016. Memory-icon swap pending Jamee's
  asset filenames.
- **Code untouched.** This was a docs + ADRs pass only. The Phase 2 re-open
  (engine abstraction, structured-output parity, download/lifecycle) is a
  separate implementation effort with its own plan and approval gate.

(Phase 4 closed 2026-05-06 — code shipped, tests green at 279, simulator
smoke passed including the Phase 4.5 chat-wiring fix-ups. The ledger
row below reads "complete." See "Notes from Phase 4" for context;
Phase 4.5 follow-ups remain outstanding.)

## Phase ledger

| # | Phase | Plan | Status |
|---|---|---|---|
| 0 | Project setup | [phase-0](plans/phase-0-project-setup.md) | complete (2026-04-30) |
| 1 | Markdown brain (no LLM) | [phase-1](plans/phase-1-markdown-brain.md) | complete (2026-05-01) |
| 2 | Inference loop | [phase-2](plans/phase-2-foundation-models-loop.md) | complete (2026-05-04) · **re-opened 2026-05-29** (engine abstraction — ADR-0012) |
| 3 | Module bridges + Tools | [phase-3](plans/phase-3-modules-and-tools.md) | complete (2026-05-05) |
| 4 | Anatomical GUI (static face) | [phase-4](plans/phase-4-anatomical-gui.md) | complete (2026-05-06) |
| 5 | Onboarding sequence | — | deferred (2026-05-06) |
| 6 | Single face rig + grille | — | not started · **re-scoped 2026-05-29** (single sprite-sheet unit; Parts/Face Creator → v2 — ADR-0013) |
| 7 | ~~Multi-b0t and Gallery~~ | — | **→ v2 (2026-05-29 — ADR-0013)** |
| 8 | Audio (minimal TTS + UI sounds) | — | not started · **shrunk 2026-05-29** (filter chain → v2 — §14 Q7) |
| 9 | IAP and trial | — | not started |
| 10 | Polish and ship | — | not started |

## Open questions on the boil

(Questions surfaced here are alive — once answered, they're closed in the relevant plan or ADR.)

- ~~Hilfer's three Part PNGs + 9 organ icons + 4 module sub-icons + 1 file icon — Jamee to deliver via Gamelabs.~~ **Superseded for v1 (2026-05-29 — ADR-0013/amendment §10):** v1 chrome/organs come from piiixl 1-bit packs (scaled up, runtime mask-tinted) and the face is a single sprite-sheet unit. The Gamelabs three-Part placeholders defer to v2 with the modular face. New asset task: source/slice the piiixl packs (Aseprite) + author the single-unit face sprite sheet + grille; drop into `b0tApp/Resources/Assets.xcassets/`.

## Specs in flight

- [phase-5-onboarding](specs/phase-5-onboarding.md) — **deferred 2026-05-06.** Brainstorm reached a working baseline before the deferral: Q1 revised (scope reduced to the 24-beat heartbeat tutorial only; first-60-seconds chat experience dropped); Q3 dissolved (`enabled && current_beat <= total_beats` is the source of truth for "in onboarding"); Q5 settled (runtime short-circuits the LLM, reads the beat verbatim, increments the counter, writes the journal entry — no urgency check in v1); Q6 settled (skip via the existing Phase 4 frontmatter-toggle on `enabled`, zero new GUI work). Q8 (implementation surface) and Q9 (test strategy) were the remaining open questions when we paused. Resume only after the features the beats reference are built or the beat content is pruned to match what ships.

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

## Notes from Phase 4

- Spec at `docs/specs/phase-4-anatomical-gui.md` settled 2026-05-05 from a brainstorm pivoted by Jamee mid-stream (defer parts/animation to Phase 6, ship one static face first). Plan at `docs/plans/phase-4-anatomical-gui.md` decomposed the spec into 64 tasks across 11 slices. Slice 0 (housekeeping + ADRs + face-roster + manufacturers.json stub) landed earlier as commit set ending `626345d`. Slices 1–9 (T10–T60) implemented in a single session on 2026-05-06 — 46 commits from `e59d1ae` (T10 WundercogPalette) to `202ac6c` (T59 BotProvisioner catalogue helper). T61/T62 visual sign-off and acceptance smoke pending Jamee on the simulator; T63 (this entry) closes the docs side; T64 will run the final test pass once visual sign-off is in.
- ADRs landed in Slice 0: 0010 (organs are anatomical subsystems — supersedes part of 0007), 0011 (defer face rig to Phase 6).
- Final test count: 279 passing across the b0tKit package suite (203 baseline → +76 across Slices 1–9). Zero failures, zero regressions. iOS app target builds for the simulator after every slice.
- New module shipped: `b0tHome` — SwiftUI shell, LCD inspection panel, frontmatter-as-controls, chat default content, full-screen markdown editor, tool-event wiring listener. Depends on `b0tFace`, `b0tDesign`, `b0tBrain`, `b0tCore`. ~15 source files + ~13 test files.
- Other public surface added: `b0tBrain.Bot.empty(at:)` factory (test ergonomics), `b0tBrain.Catalogue/{Manufacturer,BotModel,ManufacturerCatalogue}` (manufacturers.json reader), `b0tBrain.BotProvisioner.starterDefaultsFromCatalogue(bundle:)` helper, `b0tCore.ConversationManager.toolCallEvents` Combine publisher.
- Visual languages stay distinct per spec §6: Eye-screen carries the only CRT scanline overlay (`SKEffectNode` + GLSL fragment shader); LCD inspection panel is backlit warm-amber with no bloom/no scanlines (calculator/OP-1 sensibility); Skull / Jaw / organs / heart are flat pixel art with painterly lighting (nearest-neighbour filtering throughout).
- Subagent-driven development with worktree isolation worked well for parallel-friendly tasks: four cycles of parallel-implementer dispatch (Slice 2 T17–T20 four-way; Slice 3 T28–T30 three-way; Slice 5 T42–T45 four-way; Slice 6 T48–T49 two-way), every cycle merged cleanly via cherry-pick onto main with no conflicts. Worktree base was consistently stale (cut from `8409c7e` pre-Phase-4 main); the explicit "rebase onto main first" instruction in every parallel brief was load-bearing — three of four agents in Slice 2 detected the staleness independently and the explicit instruction in Slices 3/5/6 made it boilerplate.
- The plan amendment commit (`dca01f1`) recording the two recurring deviation patterns — `snake_case` → `lowerCamelCase` per `.swift-format` `AlwaysUseLowerCamelCase`, and `@MainActor` on test classes touching `SKNode.action(forKey:)` / SwiftUI `View.init` under Swift 6 strict concurrency — saved every downstream parallel agent from re-deriving the adaptations.

### Mid-phase plan-vs-as-built adaptations (well-documented in commit bodies)

- **Catalogue lives in `b0tBrain`, not `b0tCore`** as the plan specified. The plan's location would have created a circular dep (`b0tCore` already depends on `b0tBrain`; the plan also wanted `BotProvisioner` to import `b0tCore`). `b0tBrain` is the right home — same layer as `Frontmatter`/`YAMLValue` Codable shapes.
- **`BotStore(rootURL:)` doesn't exist** — `BotStore()` is parameterless (stateless actor; URLs passed per-operation). Plan's verbatim test snippets used the wrong constructor across multiple tasks.
- **`Bot.empty(at:)` didn't exist before this phase** — plan's tests called it but `Bot`'s memberwise init is internal because `BotStore` is internal. Added as a public static factory on `Bot` in commit `6f65a6c` for test ergonomics; complements the existing `BotStore().load(at: fixturesURL)` pattern.
- **`KnownFiles.heartbeatSchedule` doesn't exist** — `KnownFiles.swift` is a frontmatter-accessor extension (`mutable`/`enabled`/`botName` etc.), not URL constants. The heartbeat schedule URL lives at `bot.heartbeat.scheduleURL`. Plan kept referencing the wrong path; corrected to use `state.bot.heartbeat.scheduleURL` everywhere.
- **`BotStore.read`/`write` are async on an actor** — plan used `try? store.read(...)` and `try? store.write(...)` synchronously throughout. Corrected to `await store.read(...)` inside `async` test functions and `Task { try? await store.write(...) }` inside SwiftUI button actions to bridge the actor isolation.
- **`BotFile.synthetic(...)`, `BotFile.parse(...)`, `BotFile.serialise()`, `BotFile.relativePath` don't exist** — actual `BotFile` API is `init(fileURL:text:) throws`, `originalText: String` (raw source), `prose: String` (computed), `frontmatter[key]` (subscript), `frontmatter.keys` (public let), `settingFrontmatter(_:to:)` (returns new instance — BotFile is immutable). Plan tasks 36/45/46/49/52 used the imagined API; every task got reshaped accordingly.
- **`YAMLValue` cases:** `.string`/`.int`/`.double`/`.bool`/`.array`/`.dictionary`/`.null`. Plan used `.integer` throughout; corrected to `.int` (both in T41–T44 controls and T46 dispatch).
- **`Bootstrap` has 3 cases, not 2** — plan's T39 ContentView edit only handled `.pending` and `.ready`; `.failed(reason)` exists too. Added the missing case with a "bootstrap failed" placeholder view.
- **SwiftUI `.toolbar { ToolbarItem(.topBarTrailing) }` requires a NavigationStack** which doesn't wrap `OrganInspectionView`. T52 used `.overlay(alignment: .topTrailing)` instead.
- **`.fullScreenCover` is iOS-only** — `b0tKit` builds for macOS host tests too. T52 guards with `#if os(iOS)` and falls back to `.sheet` on macOS.
- **`Bundle.module.url(forResource:withExtension:)` doesn't auto-search subdirectories** — fixtures shipped via `.copy("Fixtures")` need explicit `Bundle.module.resourceURL.appendingPathComponent("Fixtures/...")` lookup. Affected T58 ManufacturerCatalogueTests.
- **`PassthroughSubject` is not declared `Sendable`** — used `nonisolated(unsafe)` storage on the actor-bound publisher in `ConversationManager`, with `@preconcurrency import Combine` to suppress the rest of the noise.
- **`HomeView` gained an optional `toolCallEvents` parameter** beyond plan scope — plan T55 only added `.onChange`, but without listener-construction the wiring chain doesn't close. Made the publisher injection opt-in so `ContentView(bootstrap:)` callers don't break (currently passes `nil`; chat-pipeline integration in Phase 4.5 will pass `ConversationManager.toolCallEvents`).

### Phase 4 follow-ups (out of scope; tracked for Phase 4.5 or later)

- **Chat surface not wired to ConversationManager.** `ChatView.sendMessage` is a TODO from T36 — the input is captured but not routed to a `ConversationManager`. Tool-event wiring chain (publisher → listener → `state.activeWiring` → scene pulses) is built end-to-end but the chat-message trigger is missing, so the spec §14 #4 manual smoke (calendar tool call → wiring lights up) can't be exercised yet. Phase 4.5: wire `ChatView.sendMessage` to call `ConversationManager.respond(to:)`, and have `ContentView` pass that manager's `toolCallEvents` publisher into `HomeView`.
- **Tools organ surfaces a static list of the 4 shipped tools** in `ToolsDirectoryView`. Wire to a live `ToolRegistry` once one is exposed by `b0tCore`/`b0tModules`.
- **HeartInspectionContainer file goes stale after edit.** `.task(id: scheduleURL)` only re-runs when the URL changes; editing the heartbeat schedule via the EditorView writes to disk but the displayed BotFile in the container's `@State` doesn't auto-refresh. User sees the persisted content on next heart-organ re-tap. Live reload on `.fullScreenCover` dismiss is future polish.
- **Module sub-icons are interim bespoke.** Spec §7.2 calls for replacement from the eventual 12–24-symbol module-icon vocabulary (amendment §2.3); vocabulary itself is a separate design exercise.
- **Hilfer's Part PNGs + organ icons + module sub-icons + file icon** still pending Jamee delivery from Gamelabs Studio. `assets/face-parts/placeholder/Wundercog/Hilfer/` holds placeholder squares; `b0tApp/Resources/Assets.xcassets/` is empty for the Hilfer Parts and organs. Slice 10 visual sign-off (T61) blocks ledger flip from "code complete" to "complete."
- **`BotProvisioner` once-only-on-first-launch behaviour** — Phase 3 follow-up still open and now more pressing since Phase 4 ships visual assets that won't propagate to existing installs.
- **`BotProvisioner.starterDefaultsFromCatalogue(bundle:)` is informational only** in v1 — returns the starter `BotModel` but doesn't drive provisioning behavior (the bundled `default-bot/` already ships Hilfer-shaped content). Phase 6+ multi-Model expansions will use the returned defaults for variant provisioning.
- **Verdana for chat content** is a Phase-4 brainstorm decision (2026-05-05) replacing the originally-spec'd Söhne. Revisit if readability isn't right on real device — Verdana is system-provided so swappable without bundling.
- **Sendable closure warnings in tests** — capturing `var captured: YAMLValue?` inside `@Sendable` closures (T42, T43 patterns) flagged transient warnings during agent builds; didn't reproduce in clean post-merge builds. SPM's `swift test` doesn't enforce `SWIFT_TREAT_WARNINGS_AS_ERRORS` (that's iOS-app-target only). If Xcode builds start surfacing these as errors, refactor with a class-wrapped capture.

### Manual smoke verification (deferred — pending Jamee)

- **T61 RenderPreview pass:** visual fidelity check against `AnatomyView`, `ChatView`, `InspectionPanel` (heart/modules/identity), `OrganInspectionView` (heart), `EditorView` via Apple Xcode MCP `RenderPreview`. Tune `WundercogPalette` / `LCDPalette` / `CRTScanlineShader.make(intensity:lineCount:)` if needed.
- **T62 Acceptance smoke per spec §14:** walk all 10 acceptance criteria live on the simulator. Heart BPM round-trip (#6, #7) and tool-event wiring pulse (#4 — gated on the Phase 4.5 chat-pipeline wiring above) are the load-bearing ones.
- **T64 final verification:** `swift test` (already 279 green) + commit summary, gated on T61/T62 outcome.

### Documentation drift to refresh (post-phase-close)

- `CLAUDE.md` project-structure section doesn't list `b0tHome/` as a module — add to the b0tKit/Sources tree.
- `b0tApp/Sources/App/ContentView.swift` was rewritten in T39; the old `statusLine` variant in CLAUDE.md examples (if any) should be updated. None spotted as of close-out.
- The plan-amendment conventions block (`dca01f1`) should likely move to a project-wide convention reference if these patterns repeat in Phase 5+ — the snake_case-in-tests issue and SKNode-actor-isolation issue are not Phase-4-specific.
