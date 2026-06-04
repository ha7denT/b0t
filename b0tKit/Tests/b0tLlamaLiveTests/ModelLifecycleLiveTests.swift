import Foundation
import XCTest

@testable import b0tLlama

/// Gated (`LIVE_LLAMA=1`) e2e for the download + lifecycle path. Points the
/// manager at the shared test cache so it reuses the already-present SmolLM2
/// (exercising the "present + checksum-verified → no-op" branch) and then loads
/// it through `ModelStore`. First-ever run actually downloads (~270 MB).
final class ModelLifecycleLiveTests: XCTestCase {
    private static let file = "SmolLM2-360M-Instruct-Q4_K_M.gguf"
    private static let sha = "2fa3f013dcdd7b99f9b237717fa0b12d75bbb89984cc1274be1471a465bac9c2"
    private static let size = 270_590_880
    private static let url = URL(
        string: "https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main/"
            + "SmolLM2-360M-Instruct-Q4_K_M.gguf")!

    private static var cacheDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("b0t-tests/models", isDirectory: true)
    }

    func test_downloadVerify_thenLoadAndUnload() async throws {
        guard ProcessInfo.processInfo.environment["LIVE_LLAMA"] == "1" else {
            throw XCTSkip("LIVE_LLAMA != 1 — skipping download/lifecycle live test")
        }
        let mgr = ModelDownloadManager(modelsDirectory: Self.cacheDir)

        let out = try await mgr.download(
            from: Self.url, filename: Self.file, expectedSHA256: Self.sha, expectedSize: Self.size)
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))

        // Second call: present + verified → no-op, same URL.
        let out2 = try await mgr.download(
            from: Self.url, filename: Self.file, expectedSHA256: Self.sha, expectedSize: Self.size)
        XCTAssertEqual(out, out2)

        // Lifecycle: load as the sole resident, then unload.
        let store = ModelStore(downloadManager: mgr)
        let runtime = try await store.load(
            modelId: "smollm2-360m-test", path: out, contextLength: 2048)
        let resident = await store.residentModelId
        XCTAssertEqual(resident, "smollm2-360m-test")
        XCTAssertGreaterThan(runtime.contextWindow, 0)

        await store.unload()
        let after = await store.residentModelId
        XCTAssertNil(after)
    }
}
