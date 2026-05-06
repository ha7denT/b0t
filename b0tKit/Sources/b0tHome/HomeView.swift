import SpriteKit
import SwiftUI

import b0tBrain
import b0tCore
import b0tDesign
import b0tFace

/// The home screen. Anatomy on top, LCD inspection panel below.
public struct HomeView: View {
    @State private var state: AnatomyState
    @State private var scene: AnatomyScene

    public init(bot: Bot, store: BotStore, initialHeartBPM: Int = 4) {
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: initialHeartBPM)
        let scene = AnatomyScene(size: CGSize(width: 390, height: 540))
        scene.installFullAnatomy(initialBPM: initialHeartBPM)
        SceneStateBridge.connect(scene: scene, state: state)
        _state = State(initialValue: state)
        _scene = State(initialValue: scene)
    }

    public var body: some View {
        VStack(spacing: 0) {
            SpriteView(scene: scene, options: [.allowsTransparency])
                .frame(maxHeight: 540)
                .background(Color(red: 0.09, green: 0.08, blue: 0.06))
            InspectionPanel(state: state)
                .frame(maxHeight: .infinity)
        }
        .ignoresSafeArea(.container, edges: .horizontal)
        .onChange(of: state.heartBPM) { _, newBPM in
            scene.heart?.startPulsing(bpm: newBPM)
        }
    }
}

#Preview("home — idle") {
    let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/preview"))
    let store = BotStore()
    return HomeView(bot: bot, store: store, initialHeartBPM: 4)
}
