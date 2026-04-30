---
description: Implement a feature from the PRD — usage /implement <PRD-section-or-feature>
---

Implement the feature named in `$ARGUMENTS`. Workflow:

1. Read the relevant section of `docs/prd.md` and `docs/design_document.md`.
2. Check `docs/decisions/` for any settled ADR that constrains this feature.
3. Check `docs/specs/` for any pre-written spec — if one exists, follow it; if not and the feature is non-trivial, write one first.
4. Use `superpowers:writing-plans` to draft an implementation plan if the feature spans multiple tasks.
5. Use `superpowers:executing-plans` or `superpowers:subagent-driven-development` to execute it.
6. Apply TDD ruthlessly for `b0tKit` modules. UI work uses `RenderPreview` for verification.
7. Honour the voice-and-copy guide for every user-facing string.
8. Verify acceptance criteria before claiming done.
