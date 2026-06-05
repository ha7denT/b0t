import XCTest
import b0tBrain
import b0tCore

@testable import b0tLlama

final class EngineHostLoaderTests: XCTestCase {
    func test_loader_returnsNil_forUndownloadedLlamaModel() async {
        // A models directory with nothing in it → llama entries are absent.
        let emptyDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let downloads = ModelDownloadManager(modelsDirectory: emptyDir)
        let store = ModelStore(downloadManager: downloads)
        let loader = EngineHost.makeProductionLoader(store: store, downloads: downloads)
        let result = await loader("qwen3-1.7b")
        XCTAssertNil(result)
    }

    func test_loader_returnsNil_forUnknownModelId() async {
        let downloads = ModelDownloadManager(
            modelsDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let store = ModelStore(downloadManager: downloads)
        let loader = EngineHost.makeProductionLoader(store: store, downloads: downloads)
        let result = await loader("nope-not-real")
        XCTAssertNil(result)
    }
}
