# 0017 — Organ-ring arrangement: left/right world-vs-mind columns, processor crown, journal organ

**Status:** Accepted
**Date:** 2026-05-31
**Deciders:** Hayden
**Supersedes (in part):** [ADR-0010](0010-organs-are-anatomical-subsystems.md)'s organ list and spatial arrangement; design doc §2.3's above/below-eye-line split.
**Source:** Hayden's home-screen mockup (`assets/ref/`), 2026-05-30/31.

## Context

ADR-0010 fixed nine organs arranged by the **eye-line** (perception/knowledge above, world-I/O below). Hayden's home-screen mockup reorganizes the ring into **two vertical columns** and aligns it with the 2026-05-29 amendment's engine-as-processor framing. The *organs-as-fixed-subsystems* principle (ADR-0010) is unchanged; only the roster and arrangement change.

## Decision

The anatomy has **ten organs**, arranged as:

- **Processor** — top crown (the 9-square chip grid flanked by the **in/out token meters**). This is ADR-0010's "Reasoning" organ **renamed**: it is now the model-management surface (engine/model selection, download, inference params; ADR-0012 / `identity/processor.md`), and the token-metering home.
- **Heart** — bottom centre. Heartbeat config (BPM, quiet hours).
- **Left column — world-facing I/O:** Network, Location, Sensors, Tools.
- **Right column — inward / mind:** Memory, Identity, Modules, **Journal**.

Two roster changes from ADR-0010:
1. **Reasoning → Processor** (rename; same crown slot; role expanded to model management per the amendment).
2. **Journal is a new organ** (right column) — surfaces the `journal/` directory (the OpenClaw log). Previously a file/section, not an organ.

The **in/out distinction survives**, re-expressed as **world-facing (left) vs. inward (right)** rather than below/above the eye-line. Direction-aware wiring pulses still apply (reads pulse organ→face, writes face→organ).

## Rationale

- **Cleaner mental model.** Left = how the b0t touches the world; right = the b0t's own mind. Easier to read at a glance than the eye-line split, and symmetric for the layout.
- **Processor, not Reasoning.** The crown organ *is* the inference engine; "Processor" matches the amendment's vocabulary and the model-management role it now carries.
- **Journal earns organ status.** It's a first-class, always-present surface the user reads (transparency of agent reasoning, design §5.4) — not a transient capability.

## Consequences

- **ADR-0010** gets a "superseded in part by 0017" header; its organs-as-subsystems principle stands, its list/arrangement are replaced by this.
- **Design doc §2.3** organ-layout prose updated (left/right columns; processor crown; ten organs incl. journal).
- **Phase 4 as-built** shipped a 9-organ ring with the eye-line split and a "Reasoning" organ — superseded; the GUI-revision work (the eventual Stage D / layout implementation) re-lays the ring per this ADR and renames Reasoning→Processor.
- The final **organ→icon mapping** and the inspector design are captured in `docs/specs/anatomical-gui-and-inspector.md`.
- No change to the *organs-as-fixed-subsystems* principle, the inspector's 3-tab model, or the semantic-palette backlights.

## When to revisit

If v2's multi-b0t or modular face introduces new always-present surfaces, the roster could grow — but the left/right world-vs-mind framing is expected to hold.
