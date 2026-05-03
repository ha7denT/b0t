import SwiftUI
import b0tBrain
import b0tCore

#if canImport(BackgroundTasks) && os(iOS)
    import BackgroundTasks
#endif

@main
struct b0tApp: App {
    @State private var bootstrap: Bootstrap = .pending
    @State private var heartbeat: HeartbeatManager?

    init() {
        registerBGTaskHandler()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(bootstrap: bootstrap)
                .task {
                    bootstrap = await Bootstrap.run()
                    await initializeHeartbeat()
                }
        }
    }

    private func registerBGTaskHandler() {
        #if canImport(BackgroundTasks) && os(iOS)
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: LiveBGTaskScheduler.taskIdentifier,
                using: nil
            ) { task in
                Task {
                    if let manager = b0tApp.shared.heartbeat {
                        _ = try? await manager.tick(trigger: .scheduled)
                        try? await manager.scheduleNext()
                    }
                    task.setTaskCompleted(success: true)
                }
            }
        #endif
    }

    private func initializeHeartbeat() async {
        guard case .ready(let bot, let store) = bootstrap else { return }

        let forceStub = ProcessInfo.processInfo.arguments.contains("--use-stub-client")
        let useDebugTimer = ProcessInfo.processInfo.arguments.contains("--debug-heartbeat-timer")

        let client: any LanguageModelClient
        if forceStub {
            client = makeProductionStub()
        } else {
            do {
                client = try LiveLanguageModelClient()
            } catch {
                client = makeProductionStub()
            }
        }

        let manager = HeartbeatManager(bot: bot, store: store, client: client)
        heartbeat = manager
        b0tApp.shared.heartbeat = manager

        try? await manager.scheduleNext()

        #if DEBUG
            if useDebugTimer {
                await manager.startDebugTimer()
            }
        #endif
    }

    private func makeProductionStub() -> StubLanguageModelClient {
        StubLanguageModelClient { context, outputType in
            if outputType == ConversationResponse.self {
                return ConversationResponse(text: "(stub) heard you")
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

    static let shared = B0tAppShared()
}

/// Tiny app-level singleton so the BG task handler closure (which runs
/// outside the SwiftUI lifecycle) can find the active HeartbeatManager.
final class B0tAppShared: @unchecked Sendable {
    var heartbeat: HeartbeatManager?
}

enum Bootstrap: Sendable {
    case pending
    case ready(Bot, store: BotStore)
    case failed(String)

    static func run() async -> Bootstrap {
        do {
            let documents = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let active = try BotProvisioner.ensureDefaultBotProvisioned(
                documentsURL: documents,
                bundle: .main
            )
            let store = BotStore()
            let bot = try await store.load(at: active)
            return .ready(bot, store: store)
        } catch {
            return .failed(String(describing: error))
        }
    }
}
