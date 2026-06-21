# Anatomical GUI + inspector — layout design note

**Status:** Design of record (ASCII-fidelity) for the GUI revision; feeds the eventual layout/inspector implementation (the amendment's "Stage D" surface).
**Date:** 2026-05-31
**Deciders:** Hayden
**Source:** Hayden's home-screen mockup (`assets/ref/iPhone 14 Pro - Phone Template (Community).png`), design session 2026-05-30/31.
**Related:** [ADR-0017](../decisions/0017-organ-ring-arrangement.md) (organ ring), [ADR-0016](../decisions/0016-aesthetic-reconciliation.md) (aesthetic), [ADR-0014](../decisions/0014-speech-via-illuminated-grille.md) (grille), [ADR-0013](../decisions/0013-v1-single-non-modular-bot.md) (single face), [ADR-0012](../decisions/0012-inference-engine-agnostic.md) (engines), [ADR-0015](../decisions/0015-content-format-boundary-slot-assembly.md) (slots/token metering).

This captures decisions reached in discussion. Fidelity is ASCII/structural by intent (Hayden: "ASCII is fine for our discussion"); a pixel-true render is deferred to implementation.

---

## 1. Home screen

```
            ▦ ▮in ▮out                  ← Processor crown + in/out token meters
   network ◯───┐   ┌───◯ memory
  location ◯───┤  ╭─────╮  ├───◯ identity      painterly face (Gamelabs sprite-sheet)
   sensors ◯───┤  │ ◉ ◉ │  ├───◯ modules       aqua eye-screen (baked), grille below
     tools ◯───┘  ╰──┬──╯  └───◯ journal
                    ♥ heart                     ← bottom centre (pink)
   ╱──────────╱─────────────╱   ⚙               ← angled divider + settings gear
  ┌──────────────────────────────────────┐
  │  lower half: chat (default) ↔ inspector │
  └──────────────────────────────────────┘
```

- **Two columns** (ADR-0017): **left = world-facing** (network, location, sensors, tools); **right = inward/mind** (memory, identity, modules, journal). **Processor** crown, **heart** bottom. Ten organs.
- **Energy wiring** connects each organ to the face; direction-aware pulses on access (reads organ→face, writes face→organ).
- **Lower half** is the chat surface by default; tapping an organ raises its inspector here (§3).
- Aesthetic per ADR-0016: painterly face in 1-bit LCD chrome; muted dark base; semantic highlights (yellow tokens / aqua function / pink heart); no bloom except the face's one emissive element.

## 2. The face (v1)

- A **Gamelabs-generated painterly animation sprite-sheet** (mood states; head rotates ≤ a few degrees).
- **Eye-screen:** baked into the sprite art, aqua-toned — looks lit, **no runtime emissive** in v1 (animated eye-screen → v2).
- **Speech grille:** the sole v1 emissive element — a **transparent cut-out** in the face sprite, lit by a **token-yellow emissive shape one z-layer behind it**, brightness driven by the speech signal (TTS amplitude, else token-rate). Per ADR-0014/0016.
- **Placeholder asset (v01):** the static head **with the grille area as transparency** is at `assets/face-parts/placeholder/WunderB0t-01/Head 04 transparent.png` (siblings: `Head 04 reduced.png`; `spritesheets/` holds the mood-state animation frames). This WunderB0t-01 placeholder demonstrates the grille mechanism above — the transparent cut-out is exactly where the behind-shape glow shows through.

## 3. Organ inspector

Tap an organ → it rises into the lower half. **Up to three tabs, rendered only if declared** (the heartbeat organ has only one). Tab strip in the header. **Panel backlight = the organ's semantic colour** (aqua functional / yellow tokens / pink heart).

- **Controls** — frontmatter-as-controls (sliders/toggles/steppers bound to frontmatter).
- **Directory** — the organ's file tree as a scrollable LCD list; tap a file → its `.md`.
- **`.md`** — renders the selected file; tap → full-screen `EditorView`.

### Generic organ — Modules (aqua)

```
┌────────────────────────────────────────────┐  panel, aqua-tinted
│ ⌁ modules        [ controls·directory·.md ] ✕│
│ ────────────────────────────────────────────│
│  CONTROLS  (enable/disable + per-module)     │
│   calendar          ▮▯ on        verbosity ▸ │  switch-N per module
│   reminders         ▮▯ on        verbosity ▸ │
│   time-awareness    ▮▯ on        verbosity ▸ │
│   weather           ▯▮ off                   │
│                                              │
│  DIRECTORY (plain list → tap opens its .md)  │
│   ▫ calendar.md             412 tok          │
│   ▫ reminders.md            380 tok       ▓  │  ◂ Scrollbar Thumb
└────────────────────────────────────────────┘
```

Decisions: **tabs as a strip**; **module enable/disable lives in Controls** (Directory is a plain list). The grammar nests — tapping a module file drills into *that module's* own Controls/`.md`.

### Processor organ — model management (yellow header)

```
┌────────────────────────────────────────────┐
│ ▦ processor      [ controls·directory·.md ] ✕│
│  CONTROLS                                    │
│   model    ◀  qwen3-1.7b  ▶                  │  catalogue cycle
│   engine   llama · Built with —              │  (FM → "foundation models")
│   temp     ━━━●━━━━━━━━━  0.7                 │  slider
│   in  ▮▮▮▮▮▮▯▯▯▯  1,510 ┐                     │  Stat Bar — prompt …
│   out ▮▮▯▯▯▯▯▯▯▯    220 ┘ / 4096 ctx          │  … + response, ONE shared ceiling
│                                              │
│  DIRECTORY = download manager (Stage C):     │
│   ✓ foundation models      (built-in)        │
│   ✓ qwen3-1.7b             0.9 GB             │
│   ↓ llama-3.2-1b   ▮▮▮▯▯ 62%  [cancel]        │  download btn + Stat Bar progress
│   ── storage 1.4 / 13 GB free ───────────    │
│  .md = model notes/readme + read-only chat   │
│        template (advanced, ADR-0015)         │
└────────────────────────────────────────────┘
```

### Token meters

Input (assembled prompt) and output (response) **share one ceiling** — the active model's context window (variable, set in Stage C1). The crown's two small bars are the glance view; the Processor Controls tab is the drill-in, with per-organ subtotals (ADR-0015 slot attribution). Tokenizer-specific; recomputed on model swap.

### Component → asset mapping (`1bit_UI_Pixel_Pack`)

| Element | Asset |
|---|---|
| Inspector frame | `UI Sprite sheet/UI_simple01/panel.png` (9-slice), runtime-tinted per organ |
| Tab strip / buttons / close | `UI Sprite sheet/UI_simple01/btn` (active = backlit) |
| Sliders (bpm, temp) | `UI Sprite sheet/UI_simple01/slider/{track,thumb,fill}` |
| Numeric steppers / model cycle | `UI Sprite sheet/Value Sliders/Value Control` + `Buttons/Retro_Menu_Buttons/Retro_Menu_Arrow0{1,2}.png` |
| Toggles | `UI Sprite sheet/Switches/switch-N` |
| Token meters + download progress | `UI Sprite sheet/UI_chains/Stat Bar` |
| Directory scroll | `UI Sprite sheet/UI_white01/Scrollbar Thumb` |

## 4. Organ → icon mapping (v01, from Hayden 2026-05-31)

Paths relative to repo root (`assets/icons/`). `2000 Pixel Icons Pack` = the 16px organ glyphs; `1bit_UI_Pixel_Pack` = processor/heart.

| Organ | Icon file |
|---|---|
| Processor | `1bit_UI_Pixel_Pack/UI Sprite sheet/UI_simple01/ico/ico 1.png` |
| Heart | `1bit_UI_Pixel_Pack/UI Sprite sheet/UI_simple01/ico/ico 9.png` |
| Network | `2000 Pixel Icons Pack/Animals & Nature/black bg/16x16px/Animals & Nature 272.png` |
| Location | `2000 Pixel Icons Pack/Interface & Objects/black bg/16x16px/Interface & Objects 561.png` |
| Sensors | `2000 Pixel Icons Pack/City & Transport/black bg/16x16px/City & Transport 58.png` |
| Tools | `2000 Pixel Icons Pack/Emoji People & Accessories/black bg/16x16px/Emoji People & Accessories 157.png` |
| Memory | `2000 Pixel Icons Pack/Interface & Objects/transparent bg/x2 32x32px/Interface & Objects 199.png` |
| Identity | `2000 Pixel Icons Pack/Interface & Objects/black bg/16x16px/Interface & Objects 715.png` |
| Modules | `2000 Pixel Icons Pack/Interface & Objects/black bg/16x16px/Interface & Objects 164.png` |
| Journal | `2000 Pixel Icons Pack/Interface & Objects/black bg/16x16px/Interface & Objects 474.png` |

**Notes:** v01 picks — to eyeball at 16px when the ring is wired (Network from "Animals & Nature" and Sensors from "City & Transport" are unexpected categories; confirm they read correctly). Memory is sourced from the 32px transparent set (others are 16px black-bg) — normalise on import. These are the runtime mask-tint targets (per ADR-0016), tinted aqua for organs, pink for heart, with the processor's meters in yellow.

## 5. Open / feeds implementation

- This design is **gated for implementation on Stage C** (engine selection + download manager + variable budgeting), which itself waits on the §14 Q6 model lineup.
- Not yet designed: home-screen **focus/chat states** (tap-face zoom; chat ↔ inspect transitions) and the **first-run** view.
- The icon set is **v01**; final glyphs + the 16px legibility pass happen at wiring time.
