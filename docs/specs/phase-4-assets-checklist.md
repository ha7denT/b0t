# Phase 4 — asset readiness checklist

Pre-spec input. Phase 4 (Anatomical GUI / default face) cannot be specced honestly until we know which assets are in hand vs. still being made. Tick each row — a missing asset surfaced now is cheap; one surfaced mid-implementation is not.

Derived from PRD §3 Phase 4 + §5.4 (`b0tFace`) + §5.6 (heartbeat) + design doc §3 (aesthetic) and §6 (Face Creator parts: Skull / Eyes / Jaw).

## Status legend

- `[x]` — delivered, in repo (note path)
- `[~]` — partial / in progress (note what's missing)
- `[ ]` — not started
- `[—]` — deferred to a later phase (note which)

---

## 1. Default face rig — the long pole

Three parts (Skull, Eyes, Jaw) × 8 mood states (idle, speaking, thinking, surprised, sleepy, attentive, worried, delighted), bundled per part as `SKTextureAtlas`-compatible PNG sets at native pixel-art resolution.

| | Item | Status | Notes / path |
|---|---|---|---|
| 1.1 | Skull — 8 mood frames | `[ ]` | |
| 1.2 | Eyes — 8 mood frames + blink loop (3–4 frames inside `idle`) | `[ ]` | |
| 1.3 | Jaw — 8 mood frames + speaking mouth cycle (2–4 frames) | `[ ]` | |
| 1.4 | Frames named for atlas convention (`<mood>_NN.png`) | `[ ]` | |
| 1.5 | All three parts share a single registration grid so they composite cleanly | `[ ]` | |
| 1.6 | Designed at 1× pixel-art resolution, not pre-scaled | `[ ]` | nearest-neighbour upscaling at runtime per PRD §5.4 |

**Defines "ready":** drop the three folders into `assets/face-parts/<part>/` and an `SKTextureAtlas` per folder loads without missing-frame warnings.

## 2. Heart

| | Item | Status | Notes / path |
|---|---|---|---|
| 2.1 | Pulse loop — minimum 2-frame, ideally 4-frame (systole/diastole) | `[ ]` | |
| 2.2 | Paused / still variant (trial-expired, quiet hours) | `[ ]` | |

## 3. Organs

Phase 3 shipped 4 live modules (Calendar, Reminders, Time-Awareness, Health). Design doc §4.2 commits v1 to 10 modules total. Phase 4 ships icons for the live modules and reserves layout slots for the rest.

| | Item | Status | Notes / path |
|---|---|---|---|
| 3.1 | Calendar organ — idle + active-pulse | `[ ]` | |
| 3.2 | Reminders organ — idle + active-pulse | `[ ]` | |
| 3.3 | Time-Awareness organ — idle + active-pulse | `[ ]` | |
| 3.4 | Health organ — idle + active-pulse | `[ ]` | |
| 3.5 | Disabled-slot silhouettes for the 6 remaining v1 modules | `[ ]` | so the ring isn't visibly half-empty as later phases enable them |
| 3.6 | Anatomical-layout reference (which organ sits where on the body) | `[ ]` | design doc §3 says ear-line splits "in" vs "out" — needs concrete placement spec from Jamee |

## 4. Palette

| | Item | Status | Notes / path |
|---|---|---|---|
| 4.1 | Default palette (1 of 12 — warm-phosphor cassette-futurism baseline) | `[ ]` | amber / green / cream — never blue, per design doc §3.5 |
| 4.2 | Palette schema — named colour roles (`bg`, `phosphor`, `phosphor-dim`, `text`, `chrome`, …) | `[ ]` | format settled in the spec (JSON vs. Swift literal) |

## 5. Type

| | Item | Status | Notes / path |
|---|---|---|---|
| 5.1 | IoskeleyMono NL — system / UI / brain | `[x]` | `assets/fonts/IoskeleyMono-NL/` |
| 5.2 | Söhne — chat (licensed) | `[ ]` | if not arriving in time, Phase 4 can ship chat in IoskeleyMono and revisit. Flag explicitly in the spec. |

## 6. Chrome / chat surface

| | Item | Status | Notes / path |
|---|---|---|---|
| 6.1 | Chat-surface frame / divider treatment | `[ ]` | code-drawable; only needs an asset if Jamee wants a textured edge |

---

## Procedural — no asset required (for awareness only)

- Wiring lines (face ↔ organs) — `SKShapeNode` / shader, runtime-drawn.
- CRT / scanline overlay — `SKEffectNode` + fragment shader (PRD §5.4 SHOULD).
- Privacy-shield overlay — SwiftUI semi-transparent layer.

## Out of scope for Phase 4 — deferred

- Sounds — Phase 8 (`b0tAudio`).
- App icon — Phase 10 (polish & ship).
- Mood-variant notification icons — rendered (not hand-drawn) at face-creation time per PRD §5.8. The *default* face's variants can be pre-rendered in Phase 4 if convenient; user-face variants wait for Phase 6 (Face Creator).
- Remaining 11 palettes — Phase 6 territory.

---

## Open questions for Jamee

1. **Where is the face kit?** Purchased, custom, hybrid? PRD §12 Q4 is "resolved" but resolved ≠ delivered.
2. **One face or visual identity tied to the name?** Design doc names the default `b0t-01`. Is the default rig generic, or named/themed?
3. **Söhne — licensed and acquired, or aspirational?** Determines whether chat ships with two type families or one.
4. **Anatomical placement** — sketch/mock from Jamee, or settle in the spec?
5. **Native pixel-art canvas size** — what's the design grid for the face? Drives retina scale factor and asset import.

---

## Once this checklist is complete

→ Kick off `superpowers:brainstorming` for Phase 4 with the asset reality known.
→ Brainstorm settles design questions (layout maths, mood-state fidelity, performance budget, etc.).
→ Output is `docs/specs/phase-4-anatomical-gui.md`.
→ Then plan, then implement — mirroring Phases 1–3.
