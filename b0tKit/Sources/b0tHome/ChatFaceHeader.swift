import SpriteKit
import SwiftUI

import b0tBrain
import b0tDesign
import b0tFace

/// Chat-mode header (ADR-0019): a small, centred face above the conversation
/// feed. The face is a face-only `AnatomyScene` (no organs); tapping it toggles
/// to workbench via the shared `SceneStateBridge` wiring. Below it: the b0t name
/// + heart glyph and the toggle hint.
public struct ChatFaceHeader: View {
    @Bindable var state: AnatomyState
    @State private var scene: AnatomyScene

    public init(state: AnatomyState) {
        self.state = state
        _scene = State(initialValue: Self.makeFaceScene(state: state))
    }

    /// Builds a face-only scene wired to the same state (face tap → toggleMode).
    @MainActor
    static func makeFaceScene(state: AnatomyState) -> AnatomyScene {
        let scene = AnatomyScene(size: CGSize(width: 256, height: 256))
        scene.installWunderFace()
        SceneStateBridge.connect(scene: scene, state: state)
        return scene
    }

    public var body: some View {
        VStack(spacing: 2) {
            SpriteView(scene: scene, options: [.allowsTransparency])
                .frame(width: 72, height: 72)
                .background(Color.clear)
            Text("b0t-01 · ♥")
                .font(Typography.systemMono(size: 11))
                .foregroundStyle(LCDPalette.textDim)
            Text("tap face → workbench")
                .font(Typography.systemMono(size: 9))
                .foregroundStyle(LCDPalette.textDim.opacity(0.7))
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }
}

#Preview("chat — face header") {
    let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/preview"))
    let store = BotStore()
    let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
    return ChatFaceHeader(state: state).background(Color.black)
}
