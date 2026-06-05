import Foundation
import b0tBrain
import b0tCore
import b0tHome
import b0tLlama

/// App-level holder for the shared inference runtime: one `EngineHost` (used by
/// the heartbeat, the chat manager, and the Processor inspector), plus the
/// download coordinator + processor controller the inspector binds to. Building
/// it once and sharing it is what makes "switch the model in the inspector →
/// chat + heartbeat use the new model" work (Stage D, approach A).
@MainActor
final class ProcessorRuntime {
    let engineHost: EngineHost
    let processorController: AppProcessorController
    let downloadCoordinator: ModelDownloadCoordinator

    private init(
        host: EngineHost, controller: AppProcessorController,
        coordinator: ModelDownloadCoordinator
    ) {
        self.engineHost = host
        self.processorController = controller
        self.downloadCoordinator = coordinator
    }

    /// Build the shared runtime: resolve the initial engine (same logic as the
    /// old resolveClient), wrap it in an EngineHost with a ModelStore-backed
    /// loader, and construct the inspector seams over the SAME ModelDownloadManager.
    static func make(bot: Bot, store: BotStore, forceStub: Bool = false) async -> ProcessorRuntime {
        // One ModelDownloadManager shared by the host loader, the processor
        // controller, and the download service — so every downloaded-state check
        // looks at the same files directory.
        let downloads = ModelDownloadManager()
        let modelStore = ModelStore(downloadManager: downloads)
        let initialEngine: any LanguageModelClient
        let initialId: String
        if forceStub {
            // Debug `--use-stub-client`: start on the stub engine, but STILL build
            // the EngineHost + inspector seams over a real ModelDownloadManager /
            // ModelStore so the Processor inspector + downloads remain testable.
            initialEngine = Self.makeStub()
            initialId = InferenceModelCatalogue.foundationModelsDefault.id
        } else {
            (initialEngine, initialId) = await resolveInitialEngine(bot: bot, downloads: downloads)
        }
        let host = EngineHost(
            initialEngine: initialEngine, initialModelId: initialId,
            loader: EngineHost.makeProductionLoader(store: modelStore, downloads: downloads))
        let controller = AppProcessorController(
            bot: bot, store: store, host: host, downloads: downloads)
        let coordinator = ModelDownloadCoordinator(
            service: AppModelDownloadService(downloads: downloads))
        return ProcessorRuntime(host: host, controller: controller, coordinator: coordinator)
    }

    /// Mirrors the old `b0tApp.resolveClient`'s initial-engine resolution,
    /// returning the concrete engine + its catalogue id. Falls back to FM (then
    /// stub) when the selected llama model isn't present or fails to load.
    private static func resolveInitialEngine(
        bot: Bot, downloads: ModelDownloadManager
    ) async -> (any LanguageModelClient, String) {
        let processorEngine: String?
        let processorModelId: String?
        if let processor = try? await bot.identity.processor {
            processorEngine = processor.processorEngine
            processorModelId = processor.processorModelId
        } else {
            processorEngine = nil
            processorModelId = nil
        }

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

        func fmOrStub() -> (any LanguageModelClient, String) {
            let engine: any LanguageModelClient = (try? LiveLanguageModelClient()) ?? Self.makeStub()
            return (engine, InferenceModelCatalogue.foundationModelsDefault.id)
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
                return (engine, modelId)
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

    /// Mirrors `b0tApp.makeProductionStub()` — the last-resort engine when FM is
    /// unavailable on the device (e.g. simulator without Apple Intelligence).
    private static func makeStub() -> StubLanguageModelClient {
        StubLanguageModelClient { _, outputType in
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
}
