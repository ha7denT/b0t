import XCTest

@testable import b0tBrain
@testable import b0tCore

final class EngineSelectorTests: XCTestCase {
    func test_declaredEngineMapping() {
        XCTAssertEqual(EngineSelector.declaredEngine(fromProcessorEngine: "llama"), .llama)
        XCTAssertEqual(
            EngineSelector.declaredEngine(fromProcessorEngine: "foundation_models"),
            .foundationModels)
        XCTAssertEqual(EngineSelector.declaredEngine(fromProcessorEngine: nil), .foundationModels)
        XCTAssertEqual(
            EngineSelector.declaredEngine(fromProcessorEngine: "garbage"), .foundationModels)
    }

    func test_declaredFM_whenAvailable_picksFM() {
        let r = EngineSelector.resolve(
            processorEngine: "foundation_models", modelId: nil, fmAvailable: true,
            downloadedModelIds: [])
        XCTAssertEqual(r, .foundationModels)
    }

    func test_declaredFM_whenUnavailable_fallsBackToLlama_missingIfNotDownloaded() {
        // FM declared but unavailable → CapabilityDetector falls back to llama;
        // default model not downloaded → missing.
        let r = EngineSelector.resolve(
            processorEngine: "foundation_models", modelId: nil, fmAvailable: false,
            downloadedModelIds: [])
        XCTAssertEqual(r, .llamaModelMissing(modelId: InferenceModelCatalogue.qwen3.id))
    }

    func test_declaredLlama_downloaded_picksThatModelWithItsContextWindow() {
        let r = EngineSelector.resolve(
            processorEngine: "llama", modelId: "qwen2.5-1.5b", fmAvailable: true,
            downloadedModelIds: ["qwen2.5-1.5b"])
        XCTAssertEqual(
            r,
            .llama(
                modelId: "qwen2.5-1.5b",
                contextLength: InferenceModelCatalogue.qwen25.contextWindow))
    }

    func test_declaredLlama_unknownModelId_fallsBackToDefaultModel() {
        let r = EngineSelector.resolve(
            processorEngine: "llama", modelId: "does-not-exist", fmAvailable: true,
            downloadedModelIds: [InferenceModelCatalogue.qwen3.id])
        XCTAssertEqual(
            r,
            .llama(
                modelId: InferenceModelCatalogue.qwen3.id,
                contextLength: InferenceModelCatalogue.qwen3.contextWindow))
    }

    func test_declaredLlama_notDownloaded_reportsMissing() {
        let r = EngineSelector.resolve(
            processorEngine: "llama", modelId: "llama-3.2-1b", fmAvailable: true,
            downloadedModelIds: [])
        XCTAssertEqual(r, .llamaModelMissing(modelId: "llama-3.2-1b"))
    }
}
