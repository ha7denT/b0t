# 0003 — SpriteKit + SwiftUI for face rigging, not Rive

**Status:** Accepted
**Date:** 2026-04-30
**Deciders:** Jamee

## Context

The b0t face is a parametrically-driven rig: face parts that animate (blink, breathe, glance, express mood) composed into a coherent character. Three candidate technologies were considered:

1. **Rive** — designer-first runtime. Rigs and animations authored in the Rive editor, exported as `.riv` binary files, played back via the iOS runtime.
2. **Spine** — similar designer-first approach, more mature in games.
3. **SpriteKit + SwiftUI** — Apple-native. `SKScene` embedded in SwiftUI via `SpriteView`. Each face part is an `SKSpriteNode`. Animations are `SKAction` sequences in Swift.

## Decision

**SpriteKit + SwiftUI.** All face rigging, animation, and rendering uses Apple-native frameworks. No Rive runtime. No Spine runtime.

## Rationale

The deciding factor is **agent editability**. Claude Code is the primary implementer. With Rive or Spine, the rig is an opaque binary authored externally — Claude Code can wire it into views and trigger states, but cannot read, modify, refactor, or test the rig itself. With SpriteKit in Swift, every animation parameter, sequence, and transition is in code that Claude Code has full access to.

Secondary factors:

- **Native Apple frameworks** is a stated project goal (per project goals — keep the stack minimal and Apple-aligned).
- **Pixel-perfect rendering out of the box** via `SKTexture.filteringMode = .nearest`. No fighting an external runtime to disable bilinear interpolation.
- **Sprite atlas tooling** is mature in Xcode — drag a folder of frames in, get an atlas. Workflow matches the pixel-art-with-painterly-lighting source material.
- **Diffability.** Animation changes show up in git diffs as readable Swift, reviewable by Jamee and editable by Claude Code.
- **One fewer dependency** — Rive's runtime adds binary size and a third-party update treadmill.

The trade-off accepted: more code than a `.riv` import would be for the same animation. This cost is borne by Claude Code, not Jamee, so it's an acceptable trade.

## Consequences

- Animation authoring is code-first. Jamee describes the desired motion in plain language; Claude Code writes the `SKAction` sequence.
- Pixel art assets are provided by Jamee (purchased kit, custom art, or combination), bundled as `SKTextureAtlas`-compatible folders.
- Each face part must declare the same set of mood states (idle, speaking, thinking, surprised, sleepy, attentive, worried, delighted) — enforced by a Swift protocol contract.
- A small motion vocabulary library is built once and reused — blink, breathe, glance, head-tilt, mood-transition. Individual parts compose these.
- For complex non-character animations (the wiring/energy-flow visualisation between face and organs), SwiftUI's native animation system or `SKEffectNode` shaders are used as appropriate.

## When to revisit

If animation requirements grow significantly beyond what a small motion vocabulary supports. If we add a designer to the team whose tooling competence is in Rive. Either case warrants reconsidering — but the Claude Code editability argument has to be re-weighed against the new context.
