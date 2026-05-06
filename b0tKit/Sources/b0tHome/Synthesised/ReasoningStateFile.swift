import Foundation

import b0tBrain

/// Synthesised "reasoning state" file. Read-only — surfaces the last decision,
/// recent token counts, and current model session age. No editable params yet.
public enum ReasoningStateFile {
    public static func make(state: AnatomyState) -> BotFile {
        let text = """
            # reasoning

            last decision: (live data here once b0tCore exposes a publisher)
            tokens in (recent): —
            tokens out (recent): —
            session age: —

            notes: this organ is read-only in v1. tunable params come later.
            """
        let url = state.bot.rootURL.appending(path: "_synth/reasoning.md")
        // swift-format-ignore: NeverForceUnwrap — synthetic literal text is invariant.
        return try! BotFile(fileURL: url, text: text)
    }
}
