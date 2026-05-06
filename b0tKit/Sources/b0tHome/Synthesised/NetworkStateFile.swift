import Foundation

import b0tBrain

/// Synthesised "network state" file. Architecture-without-module — on-device-only
/// per ADR-0001; the organ exists for when network-dependent modules land.
public enum NetworkStateFile {
    public static func make(state: AnatomyState) -> BotFile {
        let text = """
            # network

            no network access in v1. on-device only — see ADR-0001.
            this organ exists for when network-dependent modules land.
            """
        let url = state.bot.rootURL.appending(path: "_synth/network.md")
        // swift-format-ignore: NeverForceUnwrap — synthetic literal text is invariant.
        return try! BotFile(fileURL: url, text: text)
    }
}
