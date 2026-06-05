import Foundation
import b0tBrain
import b0tCore
import b0tHome
import b0tLlama

/// Production `ProcessorControlling`: persists the selection to `processor.md`
/// and re-resolves the live `EngineHost`. Spec §4.
///
/// Shares the same `ModelDownloadManager` instance as the rest of the runtime so
/// downloaded-state checks here agree with the host's loader and the download
/// service (see `ProcessorRuntime.make`).
final class AppProcessorController: ProcessorControlling, @unchecked Sendable {
    private let bot: Bot
    private let store: BotStore
    private let host: EngineHost
    private let downloads: ModelDownloadManager

    init(bot: Bot, store: BotStore, host: EngineHost, downloads: ModelDownloadManager) {
        self.bot = bot
        self.store = store
        self.host = host
        self.downloads = downloads
    }

    func currentSelection() async -> (engineLabel: String, modelId: String) {
        let id = host.activeModelId
        let entry = InferenceModelCatalogue.entry(id: id)
        let label: String
        switch entry?.engine {
        case .foundationModels: label = "foundation models"
        case .llama: label = "llama · \(entry?.license ?? "")"
        case .none: label = "—"
        }
        return (label, id)
    }

    func selectModel(id: String) async -> ModelSelectionOutcome {
        if let entry = InferenceModelCatalogue.entry(id: id),
            let file = try? await store.read(bot.identity.processorURL)
        {
            let updated =
                file
                .settingFrontmatter("engine", to: .string(entry.engine.rawValue))
                .settingFrontmatter("model_id", to: .string(id))
            try? await store.write(updated)
        }
        return await host.selectModel(id: id)
    }

    func downloadedModelIds() async -> Set<String> {
        var ids: Set<String> = []
        for entry in InferenceModelCatalogue.downloadable {
            if let file = entry.file,
                await downloads.isDownloaded(filename: file, expectedSize: entry.sizeBytes)
            {
                ids.insert(entry.id)
            }
        }
        return ids
    }
}
