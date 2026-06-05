import SwiftUI
import b0tBrain
import b0tCore
import b0tLlama
import b0tModules

#if canImport(BackgroundTasks) && os(iOS)
    import BackgroundTasks
#endif

@main
struct b0tApp: App {
    @State private var bootstrap: Bootstrap = .pending
    @State private var heartbeat: HeartbeatManager?
    @State private var processorRuntime: ProcessorRuntime?

    init() {
        registerBGTaskHandler()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(bootstrap: bootstrap, processorRuntime: processorRuntime)
                .task {
                    bootstrap = await Bootstrap.run()
                    if case .ready(let bot, let store) = bootstrap {
                        // Build the single shared inference runtime once at startup.
                        // Its EngineHost is reused by the heartbeat, the chat
                        // manager, and the Processor inspector (Stage D, approach A),
                        // so switching the model in the inspector takes effect
                        // everywhere.
                        let forceStub = ProcessInfo.processInfo.arguments
                            .contains("--use-stub-client")
                        let rt = await ProcessorRuntime.make(
                            bot: bot, store: store, forceStub: forceStub)
                        processorRuntime = rt
                        b0tApp.shared.processorRuntime = rt
                        await initializeHeartbeat(runtime: rt)
                    }
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

    private func initializeHeartbeat(runtime: ProcessorRuntime) async {
        guard case .ready(let bot, let store) = bootstrap else { return }

        let useDebugTimer = ProcessInfo.processInfo.arguments.contains("--debug-heartbeat-timer")

        // The heartbeat always drives the shared EngineHost. In forceStub mode the
        // host wraps the stub engine, which is the correct behaviour.
        let client: any LanguageModelClient = runtime.engineHost
        let modelIdProvider: @Sendable () -> String = {
            [host = runtime.engineHost] in host.activeModelId
        }

        let modules: [any Module]
        do {
            modules = try await ModuleRegistry.loadModules(for: bot)
            print(
                "[b0t] (heartbeat) loaded \(modules.count) modules: \(modules.map { type(of: $0).id })"
            )
        } catch {
            print("[b0t] (heartbeat) ModuleRegistry.loadModules threw: \(error)")
            modules = []
        }
        let tools = modules.flatMap(\.tools)
        let toolsRequirePermission = modules.contains { !$0.requiredPermissions.isEmpty }

        let manager = HeartbeatManager(
            bot: bot,
            store: store,
            client: client,
            tools: tools,
            toolsRequirePermission: toolsRequirePermission,
            modelIdProvider: modelIdProvider
        )
        heartbeat = manager
        b0tApp.shared.heartbeat = manager

        try? await manager.scheduleNext()

        #if DEBUG
            if useDebugTimer {
                await manager.startDebugTimer()
            }
        #endif
    }

    static let shared = B0tAppShared()
}

/// Tiny app-level singleton so the BG task handler closure (which runs
/// outside the SwiftUI lifecycle) can find the active HeartbeatManager.
final class B0tAppShared: @unchecked Sendable {
    var heartbeat: HeartbeatManager?
    /// The shared inference runtime (Stage D). `ProcessorRuntime` is
    /// main-actor-isolated and is built and read only from MainActor contexts
    /// (`initializeHeartbeat`, the inspector wiring in 15b). The property holds a
    /// reference only; the class stays `@unchecked Sendable` so the BG-task
    /// closure can keep touching `heartbeat` off the main actor.
    var processorRuntime: ProcessorRuntime?
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
