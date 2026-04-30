---
mutable: true
always_in_context: false
tts_enabled: false
filter: "tape"
pitch: 0
rate: 0.5
---

# audio

how I sound, when I speak aloud. TTS is off by default — set `tts_enabled: true` if you want me to speak.

I'm text-first. voice is opt-in for two reasons: stock TTS without character feels like a service, not a device, and audio in shared spaces gets awkward fast.

## filters

eight audio filters ship with v1. each is a chain of effects applied to the system TTS voice.

- **`clean`** — passthrough. system voice, untouched.
- **`warm`** — gentle low-pass and EQ boost in the low-mids. friendly.
- **`tape`** (default) — slight pitch wobble, low-pass at 6kHz, gentle saturation. wow-and-flutter. cassette futurism, the brand voice.
- **`fm`** — high-pass, narrow bandpass, slight distortion, mono. like an old FM transmission.
- **`radio`** — bandpass 400Hz–4kHz, light noise floor. transmission artefacts.
- **`distant`** — heavy reverb, low-pass, reduced amplitude. like I'm in another room.
- **`vintage`** — bit reduction, slight aliasing, warm EQ. early sample-playback machine.
- **`hi-fi`** — clean with subtle stereo enhancement and harmonic excitement.

pick one in `filter:` above. you can preview filters in the audio settings panel.

## parameters

- **`pitch`:** −10 (lower) to +10 (higher). 0 is neutral.
- **`rate`:** 0.0 (very slow) to 1.0 (very fast). 0.5 is comfortable conversation pace.

these stack with the filter — a `tape` filter at +3 pitch and 0.4 rate sounds different from `tape` at default.

## constraints

- TTS uses Apple's `AVSpeechSynthesizer` routed through `AVAudioEngine` for the filter chain. all on-device, no network.
- voice options are limited to what iOS provides. you can choose a different voice in iOS Settings → Accessibility → Spoken Content; b0t uses the selected default.
- some filters work better with some voices. if a filter sounds wrong, try a different system voice.

## notifications

even with TTS enabled, notifications are silent unless you've also configured iOS notification sounds. b0t doesn't speak push notifications aloud.
