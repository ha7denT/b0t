import Foundation
import b0tCore

/// The seam the Processor Controls tab binds to: read the current engine/model,
/// switch models (writing `processor.md` + re-resolving the live engine), and
/// learn which catalogue models are downloaded. Production conformer
/// (`AppProcessorController`) lives in `b0tApp`. Spec §4/§7.
public protocol ProcessorControlling: AnyObject, Sendable {
    func currentSelection() async -> (engineLabel: String, modelId: String)
    func selectModel(id: String) async -> ModelSelectionOutcome
    func downloadedModelIds() async -> Set<String>
}

/// Test/preview double.
public final class StubProcessorController: ProcessorControlling, @unchecked Sendable {
    private let engineLabel: String
    private let modelId: String
    private let downloaded: Set<String>
    public init(engineLabel: String, modelId: String, downloaded: Set<String>) {
        self.engineLabel = engineLabel
        self.modelId = modelId
        self.downloaded = downloaded
    }
    public func currentSelection() async -> (engineLabel: String, modelId: String) {
        (engineLabel, modelId)
    }
    public func selectModel(id: String) async -> ModelSelectionOutcome {
        downloaded.contains(id) || id == "foundation_models_default"
            ? .active(modelId: id) : .missing(modelId: id)
    }
    public func downloadedModelIds() async -> Set<String> { downloaded }
}
