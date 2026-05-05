# 0011 — Defer face rig to Phase 6

**Status:** Accepted
**Date:** 2026-05-05
**Deciders:** Jamee
**Amends:** PRD §3 Phase 4, §5.4

## Context

PRD §3 Phase 4 originally bundled the anatomical GUI shell *and* the rigged face (8 mood states per Part, blink loop, breathing, mouth-open cycle) together. The face rig requires the parts ontology, atlases, mood-state machines, and the 12-Manufacturer × 3-Model roster being delivered — most of which is content rather than engineering.

Phase 4 brainstorming on 2026-05-05 settled a tighter scope: validate the cassette-futurism look on glass with a single static face, defer rig + parts library + Face Creator into Phase 6 as one consolidated content phase.

## Decision

Phase 4 ships:
- One static face: **Hilfer** (Wundercog tier-1 starter Model), composed of three baked PNGs (Skull / Eye-screen / Jaw) per the amendment §2.1 three-Parts ontology.
- The full anatomical GUI shell: 9-organ ring, beating heart, pulsing wiring, backlit-LCD inspection panel doubling as chat.
- Decal layer **architecturally present**, no Hilfer decal assets.

Phase 6 (consolidated) absorbs:
- Face rig (mood states, blink, breathing, mouth-open cycle) — the SpriteKit mood-state machine over Part atlases.
- Parts library (Skull / Eyes / Jaw variants from across the roster).
- Face Creator UX (composition, randomise, save).
- Mood-variant notification icons.

## Rationale

- **Validate the look first.** A static face in the GUI shell tests the cassette-futurism aesthetic, the LCD inspection pattern, the 9-organ ring layout, and the wiring/heart procedural visuals — without committing to rig animation choices.
- **Phase 4 stays buildable.** With the rig and parts library deferred, Phase 4's asset surface collapses from ~30+ rigged sprite frames to 3 static PNGs + 9 organ icons + 4 module sub-icons + 1 file icon.
- **Phase 6 becomes additive, not invasive.** Approach 2 (SpriteKit-first hybrid) means Phase 6 swaps in atlases and a mood-state machine without architectural rewrites — the eventual home of the rig is exercised from Phase 4.

## Consequences

- PRD §3 Phase 4 acceptance is rewritten in this amendment.
- PRD §3 Phase 6 absorbs rig + parts + Face Creator (previously Phase 6 was Face Creator alone).
- PRD §5.4 prefaced with "rig ships in Phase 6."
- Aesthetic discipline still applies to Hilfer's three Part PNGs and the procedural wiring/heart/LCD.
- Procedural-animation guidance for the rig is captured in a separate session (forthcoming spec).
