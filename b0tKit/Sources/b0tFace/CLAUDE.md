# b0tFace

The face rig — SpriteKit + SwiftUI rendering of the b0t's animated face.

## Public API contracts (target shape)

- `FaceScene: SKScene` — hosts face parts as `SKSpriteNode`s.
- `FaceRig` — orchestrates parts into the 8 mood states (idle, speaking, thinking, surprised, sleepy, attentive, worried, delighted).
- `MoodStateMachine` — transitions between mood states.
- `CRTOverlay: SKEffectNode` — optional scanline shader.
- SwiftUI host: `FaceView` wrapping `SpriteView`.

## Patterns

- **Nearest-neighbour scaling always.** `SKTexture.filteringMode = .nearest`. Never bilinear. Pixel grid must survive retina scaling.
- Every shipped face part has all 8 mood states baked in. New parts must conform.
- Animations are `SKAction` sequences in Swift — diffable in git.
- Pixel art assets are provided by Jamee; we integrate, we do not generate.

## Depends on

- `b0tDesign` (palettes, tokens)

## Read first when working here

- `docs/prd.md` §5.4
- `docs/design_document.md` §3 (aesthetic), §2.5 (Face Creator)
- ADR 0003 (SpriteKit over Rive)
- `assets/face-parts/`, `assets/palettes/`
