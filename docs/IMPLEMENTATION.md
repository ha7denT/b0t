# Implementation tracker

A living document. Updated at the end of each phase, or when a blocker appears.

## Current state

- **Phase:** 3 — Module bridges + Tools
- **Status:** not started
- **Plan:** (forthcoming — will live at `docs/plans/phase-3-*.md`)

## Phase ledger

| # | Phase | Plan | Status |
|---|---|---|---|
| 0 | Project setup | [phase-0](plans/phase-0-project-setup.md) | complete (2026-04-30) |
| 1 | Markdown brain (no LLM) | [phase-1](plans/phase-1-markdown-brain.md) | complete (2026-05-01) |
| 2 | Foundation Models loop | [phase-2](plans/phase-2-foundation-models-loop.md) | complete (2026-05-04) |
| 3 | Module bridges + Tools | — | not started |
| 4 | Anatomical GUI (default face) | — | not started |
| 5 | Onboarding sequence | — | not started |
| 6 | Face Creator | — | not started |
| 7 | Multi-b0t and Gallery | — | not started |
| 8 | Audio (TTS + effects) | — | not started |
| 9 | IAP and trial | — | not started |
| 10 | Polish and ship | — | not started |

## Open questions on the boil

(Questions surfaced here are alive — once answered, they're closed in the relevant plan or ADR.)

- (none currently — Phase 0 questions resolved 2026-04-30)

## Specs in flight

- (none currently — Phase 3 spec to be brainstormed when phase begins)

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
