import SpriteKit
import SwiftUI

import b0tBrain
import b0tCore
import b0tDesign
import b0tFace
import b0tModules

/// The home screen. Anatomy on top, LCD inspection panel below.
///
/// `.task` initializes the ConversationManager (loads bot modules, picks live
/// vs stub language-model client, constructs the manager) and stores it on
/// `AnatomyState.manager` for ChatView to use. The same task wires a
/// `ToolInvocationListener` on `manager.toolCallEvents` so wiring-network
/// pulses fire on tool invocations.
public struct HomeView: View {
    @State private var state: AnatomyState
    @State private var scene: AnatomyScene
    @State private var listener: ToolInvocationListener?
    private let bot: Bot
    private let store: BotStore

    public init(bot: Bot, store: BotStore, initialHeartBPM: Int = 4) {
        self.bot = bot
        self.store = store
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
        .task { await initializeManager() }
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

    /// Mirrors DebugBrainView's pattern: pick a live or stub language-model
    /// client, load modules via ModuleRegistry, construct the ConversationManager,
    /// then start a ToolInvocationListener subscribed to its toolCallEvents.
    /// The duplication with b0tApp.initializeHeartbeat / DebugBrainView is
    /// intentional for now — a shared init helper is a Phase 4.5+ refactor.
    private func initializeManager() async {
        guard state.manager == nil else { return }

        let forceStub = ProcessInfo.processInfo.arguments.contains("--use-stub-client")
        let client: any LanguageModelClient
        if forceStub {
            client = makeStubClient()
        } else {
            do {
                client = try LiveLanguageModelClient()
            } catch {
                client = makeStubClient()
            }
        }

        let modules: [any Module]
        do {
            modules = try await ModuleRegistry.loadModules(for: bot)
            print(
                "[b0t] (chat) loaded \(modules.count) modules: \(modules.map { type(of: $0).id })"
            )
        } catch {
            print("[b0t] (chat) ModuleRegistry.loadModules threw: \(error)")
            modules = []
        }
        let tools = modules.flatMap(\.tools)
        let toolsRequirePermission = modules.contains { !$0.requiredPermissions.isEmpty }

        let manager = ConversationManager(
            bot: bot,
            store: store,
            client: client,
            tools: tools,
            toolsRequirePermission: toolsRequirePermission
        )
        state.manager = manager

        let listener = ToolInvocationListener(
            state: state,
            source: manager.toolCallEvents.eraseToAnyPublisher()
        )
        listener.start()
        self.listener = listener
    }

    private func makeStubClient() -> StubLanguageModelClient {
        StubLanguageModelClient { context, outputType in
            if outputType == ConversationResponse.self {
                return ConversationResponse(text: "(stub) heard you: \(context.userPrompt)")
            } else if outputType == TickDecision.self {
                return TickDecision(
                    observed: "stub tick",
                    considered: ["pass"],
                    decided: "pass",
                    why: "stub mode",
                    acted: "noted silently"
                )
            } else {
                preconditionFailure("stub does not handle \(outputType)")
            }
        }
    }
}

#Preview("home — idle") {
    let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/preview"))
    let store = BotStore()
    return HomeView(bot: bot, store: store, initialHeartBPM: 4)
}
