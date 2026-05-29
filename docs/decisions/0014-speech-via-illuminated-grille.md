# 0014 — Speech signalled by an illuminated speaker grille; no moving jaw in v1

**Status:** Accepted
**Date:** 2026-05-30
**Deciders:** Jamee
**Source:** amendment 2026-05-29 §5; relates to ADR-0013 (single face) and §14 Q7 (minimal TTS).

## Context

A moving mouth/jaw multiplies the animation surface: every mood state (~8) would need a mouth-open variant, and the combinations compound (mood × mouth × speaking-or-not). For a single sprite-sheet face (ADR-0013) this is both expensive to author and a coherence risk — wrong combinations read as broken.

## Decision

**No moving mouth/jaw in v1.** Speech is signalled by a **speaker grille that illuminates**, separate from the face.

- **Two independent channels.** Mood sprites (eyes, brow) carry emotion/aliveness; the grille carries speech/activity. They never need to be combined, which removes the mood-×-mouth combinatorial problem entirely.
- **Grille intensity is driven by the speech signal.** With minimal TTS in v1 (§14 Q7), the grille tracks the **TTS amplitude envelope** when audio is playing, and **token-emission rate** for text-only output.
- **The grille pulses in the "tokens" highlight colour (yellow `#EAFF3D`)**, tying it to the token semantics (amendment §8) and the two-directional yellow energy flow (input tokens *into* the processor, output tokens *out* via the grille).

## Rationale

- **Kills the combinatorial problem.** One emotion channel, one activity channel, composed freely.
- **Diegetic and on-aesthetic.** An illuminated grille is honest cassette-futurism hardware — a speaker that lights when it speaks — not lip-sync theatre.
- **Ties speech to the token metabolism.** Output is literally the b0t spending tokens; the yellow grille makes that visible.

## Consequences

- The v1 face rig drops the jaw-open cycle; ADR-0013's sprite-sheet mood states carry expression only.
- A grille node is added to the face/anatomy composition with an intensity input bound to the active speech signal.
- The amplitude path depends on TTS being present; minimal TTS (system `AVSpeechSynthesizer`, no filter chain) ships in v1 (§14 Q7). Text-only turns fall back to token-rate.
- v2's modular face (ADR-0013) may reintroduce jaw articulation per-Part; the grille channel remains valid regardless.

## When to revisit

If v2's modular rig wants articulated mouths, the grille becomes complementary rather than the sole speech signal. The independent-channels principle still holds.
