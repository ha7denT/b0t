# b0tAudio

TTS pipeline — `AVSpeechSynthesizer` → `AVAudioEngine` → effect filter chain.

## Public API contracts (target shape)

- `Synthesizer` — produces a buffer from text via `AVSpeechSynthesizer.write(_:toBufferCallback:)`.
- `EffectFilter` enum — Clean, Warm, Tape, FM, Radio, Distant, Vintage, Hi-Fi.
- `AudioEngine` — wires the synthesizer's buffer through the chosen filter chain.
- `UISounds` — system click/thunk/transition sounds (OP-1 sensibility).

## Patterns

- TTS is **off by default.** User explicitly enables. b0t is text-first.
- Filter is per-b0t, persisted in `identity/audio.md` frontmatter.
- The Tape filter is the brand voice — slight wow-and-flutter, low-pass, gentle saturation.

## Read first when working here

- `docs/prd.md` §5.5
- `docs/design_document.md` §3.7
- `assets/sounds/`
