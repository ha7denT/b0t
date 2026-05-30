# 0014 — Speech signalled by an illuminated speaker grille; no moving jaw in v1

**Status:** Accepted
**Date:** 2026-05-30
**Deciders:** Jamee
**Source:** amendment 2026-05-29 §5; relates to ADR-0013 (single face) and §14 Q7 (minimal TTS).

## Context

A moving mouth/jaw multiplies the animation surface: every mood state (~8) would need a mouth-open variant, and the combinations compound (mood × mouth × speaking-or-not). For a single sprite-sheet face (ADR-0013) this is both expensive to author and a coherence risk — wrong combinations read as broken.

## Decision

**No moving mouth/jaw in v1.** Speech is signalled by a **speaker grille that illuminates** within the face sprite-sheet.

> **Refined 2026-05-30 (emissive mechanism).** The grille is *not* a separate overlaid node — a fixed component can't stay aligned to a Gamelabs-generated head that rotates/shifts across frames. Instead the grille is **baked into the sprite frames and made to glow by a colour-key shader** that isolates the reserved grille-yellow and animates its brightness. In **v1 the grille is the *sole* runtime-emissive element** on the face; the eye-screen is baked painterly art with no emissive shader (animated eye-screen → v2; see [ADR-0016](0016-aesthetic-reconciliation.md)).

- **Independent channels.** Mood is carried by the sprite frames themselves (eyes, brow — baked expression); the grille carries speech/activity as the one colour-keyed glow. They compose freely — no mood-×-mouth combinatorial problem.
- **Grille intensity is driven by the speech signal.** With minimal TTS in v1 (§14 Q7), the grille tracks the **TTS amplitude envelope** when audio is playing, and **token-emission rate** for text-only output.
- **The grille pulses in the "tokens" highlight colour (yellow `#EAFF3D`)**, tying it to the token semantics (amendment §8) and the two-directional yellow energy flow (input tokens *into* the processor, output tokens *out* via the grille).

## Rationale

- **Kills the combinatorial problem.** One emotion channel, one activity channel, composed freely.
- **Diegetic and on-aesthetic.** An illuminated grille is honest cassette-futurism hardware — a speaker that lights when it speaks — not lip-sync theatre.
- **Ties speech to the token metabolism.** Output is literally the b0t spending tokens; the yellow grille makes that visible.

## Consequences

- The v1 face rig drops the jaw-open cycle; ADR-0013's sprite-sheet mood states carry expression only.
- The grille glows via a colour-key shader on the reserved yellow (`#EAFF3D`) within the sprite-sheet, with a brightness uniform bound to the active speech signal — not a separate positioned node. The reserved yellow must appear *only* on the grille in the art (palette discipline on the Gamelabs generation).
- The amplitude path depends on TTS being present; minimal TTS (system `AVSpeechSynthesizer`, no filter chain) ships in v1 (§14 Q7). Text-only turns fall back to token-rate.
- v2's modular face (ADR-0013) may reintroduce jaw articulation per-Part; the grille channel remains valid regardless.

## When to revisit

If v2's modular rig wants articulated mouths, the grille becomes complementary rather than the sole speech signal. The independent-channels principle still holds.
