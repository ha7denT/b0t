import Foundation
import FoundationModels
import b0tBrain

/// The outcome of engine selection: which engine the app should construct.
///
/// Pure decision — no filesystem or engine construction. The app maps this to a
/// concrete `InferenceEngine` (FM or `LlamaEngine` from the model's path).
public enum ResolvedEngine: Sendable, Equatable {
    case foundationModels
    /// Use a downloaded llama model. `contextLength` is the catalogue window.
    case llama(modelId: String, contextLength: Int)
    /// Declared (or fell back to) llama, but the chosen model isn't downloaded
    /// yet. The app surfaces this (offer download — Stage D) and uses an interim
    /// engine in the meantime.
    case llamaModelMissing(modelId: String)
}

/// Resolves the effective inference engine from `identity/processor.md` + device
/// capability + which models are downloaded (Stage C4). Builds on C2's
/// `CapabilityDetector` (declared-vs-FM-availability) and adds the
/// model-presence gate.
public enum EngineSelector {
    /// Maps `processor.md`'s `engine` string to `EngineKind`. Unknown/absent →
    /// Foundation Models (the safe default).
    public static func declaredEngine(fromProcessorEngine raw: String?) -> EngineKind {
        switch raw {
        case InferenceEngineFamily.llama.rawValue: return .llama
        default: return .foundationModels
        }
    }

    /// Production entry point. Reads `SystemLanguageModel.default.isAvailable`
    /// and forwards to the testable overload (mirrors `CapabilityDetector`).
    public static func resolve(
        processorEngine raw: String?,
        modelId: String?,
        downloadedModelIds: Set<String>
    ) -> ResolvedEngine {
        resolve(
            processorEngine: raw, modelId: modelId,
            fmAvailable: SystemLanguageModel.default.isAvailable,
            downloadedModelIds: downloadedModelIds)
    }

    /// Pure resolution. `downloadedModelIds` is the set of catalogue ids whose
    /// files are present (the app computes this; injected here for testability).
    public static func resolve(
        processorEngine raw: String?,
        modelId: String?,
        fmAvailable: Bool,
        downloadedModelIds: Set<String>,
        catalogue: [InferenceModelEntry] = InferenceModelCatalogue.all,
        defaultLlamaModelId: String = InferenceModelCatalogue.qwen3.id
    ) -> ResolvedEngine {
        let declared = declaredEngine(fromProcessorEngine: raw)
        let resolution = CapabilityDetector.resolve(declared: declared, fmAvailable: fmAvailable)

        switch resolution.engine {
        case .foundationModels:
            return .foundationModels
        case .llama:
            // Pick the declared model if it names a real catalogue entry, else
            // the default downloadable model.
            let chosenId =
                modelId.flatMap { id in catalogue.first { $0.id == id }?.id }
                ?? defaultLlamaModelId
            guard let entry = catalogue.first(where: { $0.id == chosenId }),
                entry.engine == .llama
            else {
                // No usable llama entry → fall back to FM.
                return .foundationModels
            }
            if downloadedModelIds.contains(entry.id) {
                return .llama(modelId: entry.id, contextLength: entry.contextWindow)
            } else {
                return .llamaModelMissing(modelId: entry.id)
            }
        }
    }
}
