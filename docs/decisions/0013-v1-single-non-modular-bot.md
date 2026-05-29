# 0013 — v1 ships a single non-modular b0t; modular face, multi-b0t, and unlock economy → v2

**Status:** Accepted
**Date:** 2026-05-30
**Deciders:** Jamee
**Supersedes:** ADR-0011 (defer face rig to Phase 6). **Partially supersedes** ADR-0008 (gallery cap-6, heartbeat-unlock currency, Gamelabs baked-palette pipeline, Manufacturers-as-content → v2; retained as the v2 design).
**Source:** amendment 2026-05-29 §4, §5; §14 Q4 resolved 2026-05-30.

## Context

The 2026-05-04 amendment (ADR-0008) and the design document scoped v1 around a full apparatus: a roster of up to 6 b0ts with a Gallery, multiple Manufacturers and Models, a Parts/Decals/Palette Face Creator, and heartbeat-as-unlock-currency. None of it is built — these were Phase 6 (Face Creator) and Phase 7 (Multi-b0t + Gallery), both unstarted. The tool-first repositioning (amendment §1) and the engine rework (ADR-0012) make a leaner v1 the right call: ship one genuinely useful b0t, defer the customisation apparatus.

## Decision

**v1 ships exactly one b0t with one face. No gallery, no Face Creator, no modular parts, no unlock economy.**

- **One b0t.** PRD non-negotiable #8 softens from "single-active-heartbeat, soft-cap 6" to **single-b0t for v1.** No `_active` roster pointer surface, no Gallery view.
- **One face, single pre-composed unit.** Not runtime-composited from Skull/Eyes/Jaw parts. Mood states (~8) are authored as **sprite-sheet animations** that the rig *selects*, not assembles. The grille (ADR-0014) carries speech.
- **The heartbeat *scheduler / proactive loop* stays in v1** (design §2.2, the core autonomous mechanism). Only the **heartbeat-as-unlock-currency** role (ADR-0008) defers — it is meaningless without Models to unlock.
- **The manifest/catalogue *shape* is preserved**, populated with a single pre-composed face-unit entry, so the v2 modular system is **additive** (new manifest entries), not a re-architecture.

**Deferred to v2, conceptually preserved (do not delete):** the modular `FacePart`/`SkullNode`/`EyesNode`/`JawNode` *runtime-composited* rig, `DecalNode`, per-part palette variants, the Parts/Manufacturers/Models roster, the Face Creator, the Gallery, and heartbeat-unlock. Most of ADR-0008 and amendment 2026-05-04 §2.1–2.4 / §3.1–3.3 becomes the v2 design.

## Rationale

- **Low rework.** The deferred pieces are unstarted; this is a doc + ledger re-scope, not a code teardown.
- **Tool-first.** A single dependable b0t serves the "genuinely useful local-AI utility" thesis better than a customisation apparatus the user must navigate before getting value.
- **Additive v2.** Preserving the manifest shape means the modular system slots in later without rearchitecting.

## Consequences

- **Correction to amendment §5's framing:** the MoodController state machine, face SKAction sequences, and motion-vocabulary library are **not shipped and are not "preserved"** — they were always Phase 6 (unstarted). The v1 single-face rig (sprite-sheet mood states + grille) is **net-new work**, just against a simpler target than the modular rig. ADR-0003 (SpriteKit + SwiftUI) and the ~8-mood-state set stand as the *approach*; the implementation is forthcoming.
- **Phase ledger:** Phase 6 re-scoped to "single sprite-sheet face rig + grille" (Parts library + Face Creator → v2); Phase 7 (Multi-b0t + Gallery) → v2, off the v1 ledger.
- **Design doc §2.4, §2.5, §10** and **PRD §2 #8, §3.1 (`FaceCreator/`, `Gallery/` groups not v1)** updated.
- **Catalogue:** `BotModel.parts`/`decals`/`palette`/`heartbeatUnlockThreshold` marked v2-deferred; a single face-unit entry added. `slot` field added per ADR-0015.
- The Gamelabs/Hilfer placeholder Part PNGs (Phase 4 follow-up) are **superseded for v1** by the piiixl-based single face/organs (amendment §10); Gamelabs defers with the v2 modular system. PRD §12 Q4 re-answered.

## When to revisit

v2, when the modular Parts/Manufacturers/Models system and multi-b0t roster are scheduled. The preserved manifest shape and the v2-marked 2026-05-04 design are the starting point.
