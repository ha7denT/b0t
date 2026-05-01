# Implementation tracker

A living document. Updated at the end of each phase, or when a blocker appears.

## Current state

- **Phase:** 2 — Foundation Models loop
- **Status:** not started
- **Plan:** (forthcoming — will live at `docs/plans/phase-2-*.md`)

## Phase ledger

| # | Phase | Plan | Status |
|---|---|---|---|
| 0 | Project setup | [phase-0](plans/phase-0-project-setup.md) | complete (2026-04-30) |
| 1 | Markdown brain (no LLM) | [phase-1](plans/phase-1-markdown-brain.md) | complete (2026-05-01) |
| 2 | Foundation Models loop | — | not started |
| 3 | Skill bridges | — | not started |
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

- (none yet — first spec planned: `context-assembler.md` during Phase 2 prep)

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
