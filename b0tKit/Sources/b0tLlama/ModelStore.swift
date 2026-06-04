import Foundation

/// Owns model residency: at most **one** loaded `LlamaRuntime` at a time, freed
/// before the next loads (the 6GB-floor constraint — §14 Q6). Pairs with
/// `ModelDownloadManager` for acquisition. Primitive-param'd (model id + path);
/// the caller (C4) resolves these from the `InferenceModelCatalogue`.
public actor ModelStore {
    private let downloads: ModelDownloadManager
    private var resident: (id: String, runtime: LlamaRuntime)?

    public init(downloadManager: ModelDownloadManager = ModelDownloadManager()) {
        self.downloads = downloadManager
    }

    /// The id of the currently resident model, if any.
    public var residentModelId: String? { resident?.id }

    /// The resident runtime, if a model is loaded.
    public func currentRuntime() -> LlamaRuntime? { resident?.runtime }

    public func isDownloaded(filename: String, expectedSize: Int?) async -> Bool {
        await downloads.isDownloaded(filename: filename, expectedSize: expectedSize)
    }

    /// Loads `path` as the sole resident runtime, freeing any previously
    /// resident model first. Returns the existing runtime unchanged if the same
    /// `modelId` is already resident.
    public func load(modelId: String, path: URL, contextLength: Int) throws -> LlamaRuntime {
        if let resident, resident.id == modelId { return resident.runtime }
        // Drop the previous runtime before constructing the next so we never
        // hold two resident models (ARC frees the old; LlamaRuntime frees its C
        // model in `deinit`).
        resident = nil
        let runtime = try LlamaRuntime(modelPath: path, contextLength: contextLength)
        resident = (modelId, runtime)
        return runtime
    }

    /// Frees the resident model. Wire this to memory-pressure on the app side
    /// (jetsam mitigation); the actual pressure source is an app concern.
    public func unload() {
        resident = nil
    }
}
