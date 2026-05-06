# Phase 5 — Onboarding sequence

**Status:** Deferred 2026-05-06. Phase 5 paused before completion of the brainstorm because roughly a third of the 24 onboarding beats reference modules (mail, location, notes, weather) or features (face creator, multi-b0t) that aren't built yet. Resume only after those features ship, or after the beat content is pruned to match what's available. The brainstorm reached a working baseline before the deferral — see the "Settled so far" section; resumption picks up at Q8 / Q9.
**Started:** 2026-05-06
**Process:** `superpowers:brainstorming` skill — see `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/brainstorming/`.

---

## Pre-constrained inputs (read these first when resuming)

The Phase 5 design is heavily pre-constrained by existing material — most of the brainstorm is settling implementation choices, not new design.

- **PRD §3 Phase 5** (`docs/prd.md` line 236) — three-deliverable scope: first-60-seconds + 24-beat module + Face Creator entry point. Acceptance criteria.
- **PRD §5.7 Onboarding** (line 379) — three REQUIRED constraints: hand-scripted first-60-seconds (NOT LLM), 24-beat tutorial as `modules/onboarding.md` module, skippable.
- **Design doc §6 The first 60 seconds** (`docs/design_document.md` line 378) — second-by-second sequence spec: opens to face, types at typing pace, two soft buttons (`talk` / `hang out`), Path A idle / Path B real conversation with visible memory writes, "third wow moment" → Face Creator.
- **Design doc §6.2** — first heartbeat says `"heartbeat 1/24"` and links to `modules/onboarding.md`.
- **`default-bot/modules/onboarding.md`** — **all 24 beats fully written**. Frontmatter: `total_beats: 24, current_beat: 1, dismissible: true, enabled: true`. The module's content is locked; only the runtime behaviour needs implementation.
- **ADR-0006** — `b0t-01` is the default name; appears in the first-60-seconds dialogue ("I'm b0t-01. you just installed me, didn't you?").
- **`b0t-amendment-2026-05-04.md`** — Manufacturer/Model vocabulary (Hilfer is the Wundercog tier-1 starter Model).

## Settled so far

### Q1 — Scope (decided 2026-05-06; revised 2026-05-06)

**Original decision (superseded):** Option A — Phase 5 ships items 1 + 2 (first-60-seconds scripted state machine + 24-beat onboarding module). Face Creator deferred to Phase 6.

**Revised decision:** Phase 5 ships **item 2 only** — the heartbeat-driven 24-beat tutorial as authored in `default-bot/modules/onboarding.md`. Item 1 (the design doc §6.1 first-60-seconds button-choice + Path A/B chat experience) is dropped from Phase 5 entirely. Face Creator stays deferred to Phase 6.

Rationale: keeping the first-60-seconds in scope was forcing complex architectural decisions (prepend-new-beats, branching, per-beat trigger DSL, parallel checklist files) that weren't clearly load-bearing for launch. The 24-beat tutorial is already authored, coherent, and handles the "introduce yourself one beat at a time" job. Beat 1's existing welcome ("I just woke up for the first time…") covers the §6.1 "oh — hi" intent at the structural level; exact wording is malleable and will be revised before launch. Phase 5 becomes a small, clean phase. Item 1 may be reintroduced as a Phase 5.5 or Phase 6 follow-up if the launch experience needs more.

What this means for the rest of the brainstorm:

- **Q2** (scripted prompts vs LLM responses for Path B): moot — no Path B chat in Phase 5.
- **Q3** (first-launch detection): still settled as dissolved — `modules/onboarding.md` frontmatter (`enabled: true && current_beat <= total_beats`) is the source of truth. Detection mechanism survives the scope reduction.
- **Q4** (visible memory-write pulse during Path B): moot for Phase 5. The Phase 4 wiring/organ pulse mechanism still works for normal operation.
- **Q-Arch / Q-Trigger** (architecture for prepended beats, per-beat trigger model): walked back; both moot.
- **Q5** (heartbeat integration mechanism): now the central remaining question. How does `HeartbeatManager.tick` pick up onboarding beats from `modules/onboarding.md`?
- **Q6** (skip mechanic): still applies — what does `dismissible: true` mean in UX terms beyond editing the frontmatter?
- **Q7** ("glance occasionally" in Path A): moot.
- **Q8** (implementation surface): now narrower — where does the onboarding-aware tick path live (inside `HeartbeatManager`, in `Executor`, in a new mini-module)?
- **Q9** (test strategy): simpler — tick-path determinism testing, no LLM stubs for onboarding beats.

### Q3 — First-launch detection (decided 2026-05-06)

**Decision: Dissolved.** No new state file, no new flag. First-launch detection is the existing `modules/onboarding.md` frontmatter: `enabled: true && current_beat <= total_beats`. The b0t is "in onboarding" iff that condition holds.

Rationale: the 24-beat module already establishes the "checklist in markdown frontmatter, advance via tick" pattern. Inventing `_state/onboarding.md` would parallel-track the same information.

## Open questions in flight

(Answer these in order. Each unlocks the next.)

### Q5 — How `HeartbeatManager.tick` picks up onboarding beats (decided 2026-05-06)

**Decision: Option B + sub-(i).**

**B — runtime short-circuit, no LLM.** Before the regular tick decision, the runtime checks if onboarding is `enabled: true && current_beat <= total_beats`. If so, it reads the beat's literal text from `modules/onboarding.md`, emits it as the tick's output, increments `current_beat`, writes the journal entry, and returns. The LLM is not invoked for onboarding ticks.

**Sub-(i) — no urgency check in Phase 5.** Phase 5 always fires the onboarding beat when active. The module's "they don't crowd out other observations — if there's something more urgent to surface, the tutorial waits" promise is deferred to a Phase 5.5 follow-up. At default heartbeat cadence (~30 min), 24 beats span ~12 hours, so collisions are low-probability and a collision just means the urgent thing surfaces on the next tick.

Rationale: the 24 beats are verbatim prose. Any LLM involvement is paraphrasing roulette on a 3B local model. Option A (Module-injected instruction) is symmetric with Phase 3 but odd — a `Module` whose only job is to short-circuit the LLM. Option C (system-prompt addendum) is the most fragile. Phase 5 stays small, deterministic, testable.

### Q6 — Skip mechanic UX (decided 2026-05-06)

**Decision: Option B, zero-new-work form.** The skip mechanic reuses Phase 4's existing frontmatter-as-controls pattern. Tapping the modules organ → onboarding sub-icon opens the standard inspection view; `enabled` renders as a frontmatter toggle (already implemented in Phase 4 T41–T44). Flipping `enabled: true → false` halts the tutorial. Beat 1 of the module already teaches this affordance ("if you'd rather I stop, edit `enabled: false` above").

The `dismissible` frontmatter field stays in the markdown but is **not implemented** in Phase 5 — `dismissible: false` would gate a more prominent skip affordance, which doesn't exist yet. Phase 5.5+ may introduce one and at that point should respect `dismissible`.

Rationale: honours the b0t's "your settings live in markdown" philosophy. Zero new GUI code. The b0t's own words walk the user through the skip path. PRD §5.7's "skippable" requirement is satisfied via the existing markdown-edit path.

### Q8 — Implementation surface

Where does the onboarding-aware tick path live in code?

- **A) Inside `HeartbeatManager.tick`.** A method-level conditional checks the onboarding module before invoking the regular tick logic. Smallest code change; concentrates onboarding awareness in one place.
- **B) New short-circuit in `Executor`.** Symmetric with how regular `TickDecision` is processed today. Keeps `HeartbeatManager` thin; `Executor` already owns "decide what happens this tick."
- **C) New `OnboardingDriver` mini-module.** A standalone helper (in `b0tCore` or a new `b0tOnboarding`) that `HeartbeatManager` consults per tick. Most isolated; most ceremony for a single feature.

### Q9 — Test strategy

The 24-beat tick path is deterministic (verbatim text emit, frontmatter counter increment). Tests:
- Unit: `HeartbeatManager` (or whichever surface from Q8) with onboarding `enabled` / `disabled` / mid-flow / completed. Assert correct beat text emitted, `current_beat` advanced, journal entry written.
- Integration: production `default-bot` with onboarding enabled, fake heartbeat trigger, run through all 24 beats, assert each journal entry matches the corresponding beat content.
- No live LLM tests needed for the onboarding path (no LLM call expected). The regular-tick path's existing live tests (gated by `LIVE_TESTS=1`) keep working as today.

## Hand-off when resuming

1. Re-read the pre-constrained inputs above.
2. Confirm the Q1 revision still holds (Phase 5 = 24-beat heartbeat tutorial only).
3. Resume at Q5.
4. After Q5 / Q6 / Q8 / Q9 are settled, present design sections per the brainstorming skill, then write the spec to *this* file (replacing the brainstorm state with the settled spec — archive the question-trail as an "open-questions-settled-during-brainstorming" appendix following the Phase 1-4 spec convention).

## Spec-in-progress location

This file (`docs/specs/phase-5-onboarding.md`) — once brainstorming completes, replace the brainstorm-state content with the settled spec.
