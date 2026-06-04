import XCTest

@testable import b0tBrain

final class InferenceModelCatalogueTests: XCTestCase {
    func test_production_isFMFirstThenTrio() {
        let p = InferenceModelCatalogue.production
        XCTAssertEqual(p.count, 4)
        XCTAssertEqual(p.first?.engine, .foundationModels)
        XCTAssertEqual(
            p.map(\.id),
            ["foundation_models_default", "qwen3-1.7b", "llama-3.2-1b", "qwen2.5-1.5b"])
    }

    func test_entryLookupAndDownloadableSet() {
        XCTAssertEqual(InferenceModelCatalogue.entry(id: "qwen3-1.7b")?.displayName, "Qwen3 1.7B")
        XCTAssertNil(InferenceModelCatalogue.entry(id: "nope"))
        // All downloadable entries are llama-engine and carry full coordinates.
        let dl = InferenceModelCatalogue.downloadable
        XCTAssertFalse(dl.isEmpty)
        for e in dl {
            XCTAssertEqual(e.engine, .llama)
            XCTAssertNotNil(e.repo)
            XCTAssertNotNil(e.file)
            XCTAssertNotNil(e.sourceURL)
        }
    }

    func test_foundationModels_hasNoDownloadCoordinates() {
        let fm = InferenceModelCatalogue.foundationModelsDefault
        XCTAssertNil(fm.sourceURL)
        XCTAssertNil(fm.sha256)
        XCTAssertNil(fm.repo)
    }

    func test_trio_sourceURLPinsRevisionAndFile() {
        let q = InferenceModelCatalogue.qwen3
        let url = q.sourceURL?.absoluteString
        XCTAssertEqual(
            url,
            "https://huggingface.co/bartowski/Qwen_Qwen3-1.7B-GGUF/resolve/"
                + "dcb19155b962dbb6389f4691a982043a8e651022/Qwen_Qwen3-1.7B-Q4_K_M.gguf")
        // The production trio all carry a SHA-256 for the verify step.
        for e in [
            InferenceModelCatalogue.qwen3,
            InferenceModelCatalogue.llama32,
            InferenceModelCatalogue.qwen25,
        ] {
            XCTAssertEqual(e.sha256?.count, 64, "\(e.id) sha256 should be 64 hex chars")
            XCTAssertNotNil(e.sizeBytes)
            XCTAssertEqual(e.quant, "Q4_K_M")
        }
    }

    func test_llamaDisclosure_carriesBuiltWithLlamaAttribution() {
        // Llama 3.2 Community License requires the "Built with Llama" notice.
        XCTAssertTrue(
            InferenceModelCatalogue.llama32.disclosure.contains("Built with Llama"))
    }
}
