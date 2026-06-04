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
            client = await resolveClient(bot: bot)
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
            toolsRequirePermission: toolsRequirePermission
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

    /// Stage C4: resolve the inference engine from `identity/processor.md` +
    /// FM availability + which models are downloaded, then construct it. Falls
    /// back to FM (or the stub) when the selected llama model isn't present
    /// (the download UI is Stage D).
    private func resolveClient(bot: Bot) async -> any LanguageModelClient {
        let processorEngine: String?
        let processorModelId: String?
        if let processor = try? await bot.identity.processor {
            processorEngine = processor.processorEngine
            processorModelId = processor.processorModelId
        } else {
            processorEngine = nil
            processorModelId = nil
        }

        let downloads = ModelDownloadManager()
        var downloaded: Set<String> = []
        for entry in InferenceModelCatalogue.downloadable {
            if let file = entry.file,
                await downloads.isDownloaded(filename: file, expectedSize: entry.sizeBytes)
            {
                downloaded.insert(entry.id)
            }
        }

        let decision = EngineSelector.resolve(
            processorEngine: processorEngine, modelId: processorModelId,
            downloadedModelIds: downloaded)

        func fmOrStub() -> any LanguageModelClient {
            (try? LiveLanguageModelClient()) ?? makeProductionStub()
        }

        switch decision {
        case .foundationModels:
            print("[b0t] inference engine: foundation models")
            return fmOrStub()
        case .llama(let modelId, let contextLength):
            if let entry = InferenceModelCatalogue.entry(id: modelId), let file = entry.file,
                let engine = try? LlamaEngine(
                    modelPath: downloads.localURL(filename: file), contextLength: contextLength)
            {
                print("[b0t] inference engine: llama (\(modelId))")
                return engine
            }
            print("[b0t] llama load failed for \(modelId); falling back")
            return fmOrStub()
        case .llamaModelMissing(let modelId):
            print(
                "[b0t] selected llama model '\(modelId)' not downloaded; using fallback "
                    + "(download UI is Stage D)")
            return fmOrStub()
        }
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
