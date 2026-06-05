import XCTest
import b0tCore

@testable import b0tHome

@MainActor
final class ProcessorControllingTests: XCTestCase {
    func test_stub_reportsSelectionAndSwitch() async {
        let stub = StubProcessorController(
            engineLabel: "foundation models", modelId: "foundation_models_default",
            downloaded: ["qwen3-1.7b"])
        let sel = await stub.currentSelection()
        XCTAssertEqual(sel.modelId, "foundation_models_default")
        let outcome = await stub.selectModel(id: "qwen3-1.7b")
        XCTAssertEqual(outcome, .active(modelId: "qwen3-1.7b"))
        let missing = await stub.selectModel(id: "llama-3.2-1b")
        XCTAssertEqual(missing, .missing(modelId: "llama-3.2-1b"))
    }
}
