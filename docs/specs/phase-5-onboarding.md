# Phase 5 — Onboarding sequence

**Status:** Brainstorming in flight (paused mid-conversation 2026-05-06).
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

### Q1 — Scope (decided 2026-05-06)

**Decision: Option A.** Phase 5 ships items 1 + 2 only — first-60-seconds scripted state machine + 24-beat onboarding module. **Face Creator entry point is deferred to Phase 6** alongside the Creator itself.

Rationale: the "third wow moment" needs a real Face Creator to land as a wow moment — a stub button is a worse experience than nothing. Phase 5 closes when the conversation flow lands; the user keeps Hilfer's face until Phase 6 inserts the Face Creator hand-off.

The state machine ends with something like "I think I know enough to start. I'll be here when you need me." (or similar — copy TBD), and the home screen settles into steady state. Phase 6's first task will be inserting the Face Creator hand-off at that point.

## Open questions in flight

(Answer these in order when resuming the brainstorm. Each unlocks the next.)

### Q2 — First-60-seconds: hand-scripted vs scripted-then-LLM

PRD §5.7 says first-60-seconds is "hand-scripted, not generated... the b0t's words at this stage are written by humans, not produced by the LLM." But design doc §6 Path B describes a real conversation ("b0t starts a low-pressure conversation. No interview. No form-filling. Just talking. As the user shares, b0t writes notes to memory/about_me.md visibly").

These are in tension if Path B lasts ~3 minutes and the user is typing back. Options:

- **A) Fully hand-scripted** — Path B is a deterministic decision tree of pre-written exchanges (the b0t's responses are picked from a small set based on user input keywords or sentiment). No LLM in the first 60 seconds. Heaviest authoring lift; most predictable.
- **B) Scripted opening then LLM-driven** — the first ~3 messages (the welcome + "talk" / "hang out" prompt + the path-A-or-B kickoff) are scripted; once Path B begins, the existing `ConversationManager` takes over with a system-prompt addendum priming the b0t to write to `memory/about_me.md` after each turn. Lightest implementation; uses Phase 4's chat surface as-is.
- **C) Scripted prompts, LLM-generated b0t responses** — every turn in Path B emits a hand-written *prompt* to the LLM ("the user just said X, respond casually and note one thing about them"), capturing the user's reply, with a strict turn cap (~5-7 turns). More predictable than B, more work than B.

### Q3 — First-launch detection mechanic

What flips the home screen from "first-60-seconds mode" to "steady state"? Options:

- **A) A flag in `identity/core.md`** — frontmatter key like `onboarding_completed: false` set to `true` after the first-60-seconds finishes.
- **B) A separate state file** — `_state/onboarding.md` with a state-machine cursor (`phase: opening | path_a_idle | path_b_chat | post_face_creator | done`). More granular, cleaner separation from identity.
- **C) Detect by emptiness** — if `memory/about_me.md` is empty AND no journal entries exist AND no chat history exists, run first-60-seconds. Simpler, no new state.

### Q4 — Visible memory-write pulse during Path B

Design doc §6 Path B: "b0t writes notes to `memory/about_me.md` *visibly* — a small organ on the body lights up, the user can tap to see what b0t has written."

Phase 4 already has `state.activeWiring` and the wiring/organ pulse mechanism (commit `2f6db39`). What hooks the memory-write to that?

- **A) Executor publishes a memory-write event** — extend `b0tCore.Executor` with a `nonisolated(unsafe) memoryWriteEvents = PassthroughSubject<MemoryObservation, Never>()` (mirrors the `ConversationManager.toolCallEvents` pattern from Phase 4.5). HomeView subscribes and pulses the Memory organ.
- **B) ChatView observes the turn's `memoryObservations`** — after `await manager.respond(to:)` returns, ChatView checks `turn.response.memoryObservations` (the `[MemoryObservation]` field on `ConversationResponse`) and mutates `state.activeWiring.insert(.memory)` with the same delayed-removal Task pattern.
- **C) ToolInvocationListener gains a memory variant** — extend the existing listener to also handle memory observations (rename to `AnatomyEventListener`?).

B is simplest and stays inside the existing wiring chain.

### Q5 — 24-beat module integration with the heartbeat tick

The existing heartbeat tick (`HeartbeatManager.tick`) calls `LanguageModelClient.generate` with a `TickDecision` request. The 24-beat module needs to override the regular tick when `current_beat <= total_beats` and `enabled: true`.

- **A) New module type that participates in tick decision-making** — `OnboardingModule` is a `Module` per `b0tModules`, but instead of providing `tools` it injects a special instruction into the next tick's context ("if onboarding is active, emit beat N's pre-written text instead of generating freely"). Heartbeat picks this up via the assembler.
- **B) `Executor` short-circuit** — before the regular tick decision, `Executor` (or `HeartbeatManager` itself) checks if `modules/onboarding.md` is enabled and `current_beat <= total_beats`. If so, skips the LLM, emits the beat's literal text, increments `current_beat`, and writes the journal entry. Cleanest separation; the LLM doesn't see onboarding at all.
- **C) System-prompt addendum** — the assembler appends an onboarding addendum to every tick's instructions ("you are on beat N of onboarding. say exactly: <text>"). The LLM produces output but is constrained. Riskier (LLM may deviate).

B is cleanest but means a new code path in `HeartbeatManager`.

### Q6 — Skip mechanic UX

Onboarding can be skipped at any time per PRD §5.7. The 24-beat module supports this via `enabled: false` in its frontmatter. Two questions:

- During the **first-60-seconds**, is there a visible "skip" affordance? Or is "hang out" Path A effectively the skip (no skip control needed)?
- During the **24-beat tutorial**, the user dismisses by editing the module file (`enabled: false`) — is there a one-tap "stop the tutorial" affordance that does this for them?

### Q7 — "Glance occasionally" in Path A

Design doc §6 Path A: "b0t glances at them occasionally."

- What's a "glance"? An eye animation (Phase 6 face rig — not available)? A wiring/organ pulse with no chat message? A short LCD status line ("..." or a short observational message)?
- Frequency? Every N seconds? Random?

This may be deferable to Phase 5.5 if Phase 6 face-rig is the natural home for glance animations.

### Q8 — Implementation surface

Where does the first-60-seconds state machine live?

- **A) New module in b0tHome** — `OnboardingFlow.swift` + `OnboardingState.swift`. HomeView gates on `state.onboardingCompleted` and renders the OnboardingFlow overlay until done.
- **B) Special `Bootstrap` state** — Bootstrap detects first-launch and emits `.firstRun(bot, store)` instead of `.ready(...)`. ContentView shows an `OnboardingView` for `.firstRun`, which then transitions to `HomeView`.
- **C) Phase-5 module in b0tHome that hijacks ChatView's first messages** — leans on existing chat surface, just primes it differently.

### Q9 — Test strategy

The state machine is deterministic (per PRD §5.7), so it should be unit-testable. Path B's LLM-driven portion (if Q2 → B or C) needs the same stub-client pattern Phase 2/3 use. The 24-beat module's tick path needs integration tests against a fake heartbeat trigger.

## Hand-off when resuming

1. Re-read the pre-constrained inputs above.
2. Confirm Q1 still holds (Option A — defer Face Creator to Phase 6).
3. Resume at Q2.
4. After all questions answered, present design sections per the brainstorming skill, then write the spec to *this* file (replacing the brainstorm state with the settled spec — keep Q1's settled answer in the spec, archive Q2-Q9 as an "open-questions-settled-during-brainstorming" appendix following the Phase 1-4 spec convention).

## Spec-in-progress location

This file (`docs/specs/phase-5-onboarding.md`) — once brainstorming completes, replace the brainstorm-state content with the settled spec.
