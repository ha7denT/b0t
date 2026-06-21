# 0010 — Organs are anatomical subsystems

**Status:** Superseded in part by [0017](0017-organ-ring-arrangement.md) — the *organs-as-fixed-subsystems* principle stands, but the organ **list** (Reasoning → Processor; Journal added → ten organs) and **arrangement** (left/right world-vs-mind columns, not above/below eye-line) are replaced by ADR-0017.
**Date:** 2026-05-05
**Deciders:** Hayden
**Supersedes (in part):** ADR-0007's organ-as-module framing

## Context

ADR-0007 ("Anatomical GUI as the primary interface, not chat") and design doc §3.3 / §4.2 originally framed organs as visualisations of *modules* — calendar organ, mail organ, etc. — with an organ count that grew with the module count.

Phase 4 brainstorming on 2026-05-05 (see `docs/specs/phase-4-anatomical-gui.md`) settled a different model: organs are fixed *anatomical subsystems* of the b0t, independent of how many modules ship.

## Decision

The b0t's anatomy has nine organs, fixed across all phases:

1. **Reasoning** (top crown) — the LLM chip; 9-square grid + in/out token tanks.
2. **Memory** (above eye-line) — punch-card stack iconography; reads/writes memory files.
3. **Identity** (above eye-line) — dog-tag iconography; surfaces the `identity/` directory (the personality surface).
4. **Modules** (above eye-line) — meta-organ; surfaces individual module `.md` files. Tap → directory of modules.
5. **Sensors** (below eye-line) — STT + text-input affordance.
6. **Tools** (below eye-line) — Swiss-army-knife frame; surfaces individual tools.
7. **Network** (below eye-line) — radio-tower iconography; surfaces network-state. No v1 modules use it; the organ exists architecturally.
8. **Location** (below eye-line) — radar-sweep iconography; surfaces location-state. No v1 modules use it; the organ exists architecturally.
9. **Heart** (bottom-centre, distinguished) — heartbeat configuration; BPM and quiet hours.

Modules and tools (the per-capability units defined elsewhere) are surfaced *inside* the Modules and Tools organs respectively. The 10-module v1 library called for in design doc §4.2 still ships — those modules live as files inside the Modules organ.

## Rationale

- **Stable anatomy.** A b0t has the same number of organs whether it has 1 module installed or 10. The home screen layout doesn't shift as the user enables/disables modules.
- **Anatomical metaphor coherence.** Heart, Reasoning, Memory, Identity, Sensors are bodily *systems*. Modules and Tools are *capabilities* that pass through those systems. Treating capabilities as organs conflated levels of abstraction.
- **Future-proof.** Network and Location organs ship in Phase 4 with no associated modules. They light up later when modules that use them ship — without retrofitting the GUI layout.

## Consequences

- ADR-0007 §"Around the face" is partly superseded — the in/out distinction by ear-line still stands; "organs representing modules" does not.
- Design doc §3.3 organ language requires a small edit (organ list update).
- Design doc §4.2 module library count (10 modules) stays — modules are now content surfaced *inside* the Modules organ.
- Phase 4 spec §4.5 documents what each organ surfaces in its inspection view.
- Wiring still pulses direction-aware on capability access — calendar tool invocation pulses the *Tools* organ, not a (no-longer-existing) calendar organ.
