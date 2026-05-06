@preconcurrency import Combine
import SpriteKit
import SwiftUI
import b0tBrain
import b0tCore
import b0tDesign
import b0tFace

/// The home screen. Anatomy on top, LCD inspection panel below.
///
/// Optional `toolCallEvents` publisher (e.g. `ConversationManager.toolCallEvents`)
/// drives wiring-network pulses on tool invocations — when supplied, a
/// `ToolInvocationListener` is constructed and lifecycled with the view.
public struct HomeView: View {
    @State private var state: AnatomyState
    @State private var scene: AnatomyScene
    @State private var listener: ToolInvocationListener?

    public init(
        bot: Bot,
        store: BotStore,
        initialHeartBPM: Int = 4,
        toolCallEvents: AnyPublisher<String, Never>? = nil
    ) {
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: initialHeartBPM)
        let scene = AnatomyScene(size: CGSize(width: 390, height: 540))
        scene.installFullAnatomy(initialBPM: initialHeartBPM)
        SceneStateBridge.connect(scene: scene, state: state)
        let listener = toolCallEvents.map {
            ToolInvocationListener(state: state, source: $0)
        }
        _state = State(initialValue: state)
        _scene = State(initialValue: scene)
        _listener = State(initialValue: listener)
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
        .onAppear { listener?.start() }
        .onDisappear { listener?.stop() }
        .onChange(of: state.heartBPM) { _, newBPM in
            scene.heart?.startPulsing(bpm: newBPM)
        }
        .onChange(of: state.activeWiring) { oldSet, newSet in
            let added = newSet.subtracting(oldSet)
            for organ in added {
                scene.wiring?.pulse(organ, direction: .outbound)
                if let organNode = scene.organs[organ] {
                    organNode.node.run(organNode.activityPulseAction())
                }
            }
        }
    }
}

#Preview("home — idle") {
    let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/preview"))
    let store = BotStore()
    return HomeView(bot: bot, store: store, initialHeartBPM: 4)
}
