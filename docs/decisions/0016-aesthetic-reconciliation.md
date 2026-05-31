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
- **Eye-screen (Q2) — baked in v1, fancy in v2.** In v1 the eye-screen is **part of the painterly sprite art** with **no runtime emissive/CRT treatment** — it can look lit, but nothing animates it. (The Phase-4 `EyesNode` + scanline shader is therefore superseded for v1 and drops out with the single-sprite-sheet rework.) An animated/emissive eye-screen is deferred to **v2** alongside the modular components.
- **Speech grille — the sole v1 emissive element.** Per [ADR-0014](0014-speech-via-illuminated-grille.md), the grille is a **transparent cut-out in the face sprite, lit by a token-yellow emissive shape one z-layer behind it**, brightness-driven by the speech signal. The head rotates only a few degrees, so the cut-out stays over the behind-shape with no silhouette leak — no colour-key, no shader. In v1 it is the *only* runtime-emissive element on the face.
- **Asset pipelines (reconciled 2026-05-30).** The **face** is a **Gamelabs-generated animation sprite-sheet** (mood states), with the grille as a transparent cut-out (above) — a v1 use of Gamelabs distinct from the *v2-deferred modular per-part baked-palette* pipeline ([ADR-0013](0013-v1-single-non-modular-bot.md) / amendment §10). The **chrome/organs/icons** are piiixl 1-bit assets, runtime mask-tinted to the semantic palette. The grille cut-out must be clean and consistent across all frames (Gamelabs transparency exclusion).

## Rationale

- **Honest contrast.** Painterly character + 1-bit instrument tells the truth about the system: a crafted companion riding a constrained, legible device. A fully-1-bit face would lose the warmth; a fully-painterly UI would lie about the hardware.
- **One palette, three meanings.** Yellow/aqua/pink map cleanly to the token/function/heart semantics already wired through the GUI and token metering.
- **Emissive discipline.** In v1, exactly **one** emissive element on the face (the grille); the eyes are baked expression. Everything else is matte LCD. This keeps "activity has weight because it isn't constant" (design §1.2); v2 adds the emissive eye-screen.

## Consequences

- **Design doc:** §3.5 colour rule rewritten (done); §3.3 layer prose and §3.6 transition prose finalized to LCD-forward + painterly-face + emissive eyes/grille (this ADR unblocks them).
- **ADR-0003** (SpriteKit + SwiftUI) stands. The Phase 4 eye-screen `EyesNode` + CRT scanline shader is **superseded for v1** (the single Gamelabs sprite-sheet has no separate eye node); an emissive eye-screen returns in v2. The v1 emissive implementation is a transparent grille cut-out backed by a behind-sprite emissive shape (no shader needed).
- **`b0tDesign`:** the semantic tokens (added per amendment §9) + 1-bit mask-tint utility are the implementation; the eye-screen shader stays.
- **Layout note (separate concern):** Jamee's mockup also reorganizes the organ ring (left/right world-vs-mind columns; processor at the crown replacing the Reasoning organ; journal as a new organ). That is an *anatomical-arrangement* change to [ADR-0010](0010-organs-are-anatomical-subsystems.md), tracked separately once the layout is finalized — **not** part of this aesthetic ADR.

## When to revisit

The v2 modular face (ADR-0013) may reintroduce per-part palettes and could revisit whether the painterly register survives composition. The LCD-forward chrome + semantic palette are independent of that and expected to hold.
