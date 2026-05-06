import Foundation

import b0tBrain

/// Synthesised "location state" file. Architecture-without-module — the organ
/// exists in the GUI for when the location module ships in a later content drop.
public enum LocationStateFile {
    public static func make(state: AnatomyState) -> BotFile {
        let text = """
            # location

            no location module shipped in v1. this organ exists for when the
            location module lands in a later content drop.
            """
        let url = state.bot.rootURL.appending(path: "_synth/location.md")
        // swift-format-ignore: NeverForceUnwrap — synthetic literal text is invariant.
        return try! BotFile(fileURL: url, text: text)
    }
}
