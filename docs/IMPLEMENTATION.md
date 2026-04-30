# Implementation tracker

A living document. Updated at the end of each phase, or when a blocker appears.

## Current state

- **Phase:** 1 — markdown brain (no LLM)
- **Status:** not started
- **Plan:** (forthcoming — will live at `docs/plans/phase-1-*.md`)

## Phase ledger

| # | Phase | Plan | Status |
|---|---|---|---|
| 0 | Project setup | [phase-0](plans/phase-0-project-setup.md) | complete (2026-04-30) |
| 1 | Markdown brain (no LLM) | — | not started |
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
