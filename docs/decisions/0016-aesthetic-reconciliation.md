# 0016 — Aesthetic reconciliation: LCD-forward chrome, painterly face, emissive eye-screen, semantic palette

**Status:** Accepted
**Date:** 2026-05-30
**Deciders:** Jamee
**Source:** amendment 2026-05-29 §9; §14 Q1/Q2/Q3 resolved 2026-05-30 against Jamee's home-screen mockup (`assets/ref/`).
**Supersedes:** design document §3.5's "warm phosphor — never blue" rule; reconciles §3.3 and §3.6.

## Context

The 2026-05-29 amendment moved the display idiom toward LCD-forward (backlit monochrome, no bloom) with a three-colour semantic highlight palette, but left three aesthetic questions open because they cascade into every visual surface (§14): Q1 the b0t face's visual register, Q2 the CRT eye-screen, Q3 the formal "never blue" override. The amendment specified the aesthetic ADR be authored only once all three were confirmed. Jamee's home-screen mockup (2026-05-30) resolved them.

## Decision

A deliberate **two-register** aesthetic: a painterly face inside 1-bit LCD chrome.

- **Display idiom — LCD-forward (Q-context).** Panels, organs, chrome, and the inspection surface are backlit monochrome LCD: low-contrast, matte, visible pixel grid, **no bloom, no glow** (bloom reads as LED). Faint ghosting/persistence is on-idiom.
- **Semantic highlight palette (Q3 — "never blue" formally overridden).** Three emphasis colours over a muted dark base:
  - yellow `#EAFF3D` — tokens, text, brainpower
  - aqua `#3DEAFF` — the functional medium (I/O, plumbing, organs, modules)
  - pink `#FF3DEA` — the heartbeat / emotional core
  Most of the surface stays dark and unsaturated; colour is emphasis-only (buttons, per-organ backlights, the heart, the token meters). The prior "warm phosphor — amber/green/cream, never blue" rule is **superseded**.
- **Face register (Q1) — painterly.** The b0t face stays **pixel-art with painterly lighting** (the cream, lit, rounded Wundercog/Hilfer head), *not* 1-bit. This is intentional: the face is the one place painterly lives, set against the 1-bit aqua chrome — the contrast is the point (the character vs. the instrument that carries it).
- **Eye-screen (Q2) — emissive, kept.** The eye-screen remains the face's primary **emissive** element: an aqua-toned pixel display retaining its CRT-ish scanline/glow treatment (the `SKEffectNode` + shader shipped in Phase 4), now in aqua rather than warm phosphor. It is the one allowed exception to "no bloom" on the face.
- **Speech grille — second emissive element.** Per [ADR-0014](0014-speech-via-illuminated-grille.md), the speech grille is a separate emissive node layered over the matte painterly face, brightness-driven by the speech signal. Its colour is governed by ADR-0014 (token-yellow), giving the face two independent channels: aqua eyes (aliveness/mood) and yellow grille (speech/tokens out).
- **1-bit chrome source.** UI/organs are piiixl 1-bit assets (amendment §10), runtime mask-tinted to the semantic palette.

## Rationale

- **Honest contrast.** Painterly character + 1-bit instrument tells the truth about the system: a crafted companion riding a constrained, legible device. A fully-1-bit face would lose the warmth; a fully-painterly UI would lie about the hardware.
- **One palette, three meanings.** Yellow/aqua/pink map cleanly to the token/function/heart semantics already wired through the GUI and token metering.
- **Emissive discipline.** Exactly two emissive elements on the face (eyes, grille), each carrying a distinct channel; everything else matte LCD. This keeps "activity has weight because it isn't constant" (design §1.2).

## Consequences

- **Design doc:** §3.5 colour rule rewritten (done); §3.3 layer prose and §3.6 transition prose finalized to LCD-forward + painterly-face + emissive eyes/grille (this ADR unblocks them).
- **ADR-0003** (SpriteKit + SwiftUI) stands; the Phase 4 eye-screen CRT shader is retained (Q2), recoloured aqua.
- **`b0tDesign`:** the semantic tokens (added per amendment §9) + 1-bit mask-tint utility are the implementation; the eye-screen shader stays.
- **Layout note (separate concern):** Jamee's mockup also reorganizes the organ ring (left/right world-vs-mind columns; processor at the crown replacing the Reasoning organ; journal as a new organ). That is an *anatomical-arrangement* change to [ADR-0010](0010-organs-are-anatomical-subsystems.md), tracked separately once the layout is finalized — **not** part of this aesthetic ADR.

## When to revisit

The v2 modular face (ADR-0013) may reintroduce per-part palettes and could revisit whether the painterly register survives composition. The LCD-forward chrome + semantic palette are independent of that and expected to hold.
