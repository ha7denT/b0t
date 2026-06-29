# b0tFace — anatomy rendering

The SpriteKit scene tree for the anatomical GUI. Hosts the face (3 Parts + Decal layer),
the 9 organs, the heart, and the wiring network.

## Public surface

- `FacePart` protocol — implemented by `SkullNode`, `EyesNode`, `JawNode`. Three Parts only,
  per amendment §2.1 (Ears removed from scope).
- `SkullAnchorPoints` — `eyesSocket`, `jawHinge` in normalised (0-1) coords. Per-Part defaults
  live as static factories (`.hilferDefaults`, etc.).
- `DecalNode` — additive layer on top of Parts. Empty for Hilfer; populated as Decal assets land.
- `FaceComposite` — composes (Skull, Eyes, Jaw, Decals) with correct z-order and anchor-driven
  positioning.
- `AnatomyScene` — root SKScene; `installHilferFace()` for Phase 4. Slices 3+ add organs / heart /
  wiring; Slice 9 makes the installed Model configurable from `manufacturers.json`.
- `AnatomyView` — SwiftUI `SpriteView` wrapper.

## Phase 4 vs Phase 6

Phase 4 ships *static* Parts (one PNG each). Phase 6 introduces:
- `SKTextureAtlas` per Part with 8 mood-state frames (idle, speaking, thinking, surprised,
  sleepy, attentive, worried, delighted) — see ADR-0011.
- A mood-state machine on `FaceComposite` that drives texture switching + procedural motion
  (blink, breathing, mouth-open) per the forthcoming `face-creator-procedural-animation.md`.
- The Parts library and Face Creator UX — composition of unlocked Parts across Manufacturers.

This module's API is shaped so Phase 6 is additive — no protocol breaking changes anticipated.

## Z-order inside FaceComposite

Bottom to top:
1. **Eyes** — `SKEffectNode` wrapping the eye-screen sprite + `CRTScanlineShader`.
2. **Skull** — polymer shell with eye-cutout window.
3. **Jaw** — mounted at `Skull.anchorPoints.jawHinge`.
4. **Decals** — empty for Hilfer; future content drops add here.

## What lives in b0tHome (not here)

- `AnatomyState` — the @Observable bridge between scene events and SwiftUI views.
- `HomeView`, LCD inspection panel, chat — all SwiftUI, all in `b0tHome`.
- Touch handling that mutates `AnatomyState`. NOTE (2026-06-29): the embedded
  `SpriteView`'s `touchesBegan` does **not** receive touches in the SwiftUI
  composition, so `b0tHome` drives taps from the SwiftUI gesture layer and calls
  `AnatomyScene.routeTap(atViewPoint:)` (which `convertPoint(fromView:)` +
  `nodes(at:)` then dispatches to `tapHandler`/`faceTapHandler`). `touchesBegan`
  is kept but is effectively dead on iOS; `routeTap` is the live path. See
  ADR-0019 / `docs/specs/home-screen-two-mode-navigation.md`.
