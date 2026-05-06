import Foundation

import b0tBrain

/// Synthesised "sensors state" file — exposes a text-input toggle. STT/voice
/// configuration lives in identity/audio.md (Phase 8+).
public enum SensorsStateFile {
    public static func make(state: AnatomyState) -> BotFile {
        let text = """
            ---
            text_input_enabled: true
            ---

            # sensors

            text input toggle above. stt + voice configuration lives in identity/audio.md.
            """
        let url = state.bot.rootURL.appending(path: "_synth/sensors.md")
        // swift-format-ignore: NeverForceUnwrap — synthetic literal text is invariant.
        return try! BotFile(fileURL: url, text: text)
    }
}
