import Foundation
import XCTest

/// Downloads the SmolLM2-360M test model to a local cache on first use.
/// Skips (not fails) when LIVE_LLAMA != "1" so default `swift test` stays
/// offline and fast.
enum LlamaModelCache {
    static let modelURL = URL(
        string:
            "https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf"
    )!
    static var cacheFile: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("b0t-tests/models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("SmolLM2-360M-Instruct-Q4_K_M.gguf")
    }

    /// Returns the local model path, downloading once if absent. Throws
    /// `XCTSkip` when LIVE_LLAMA is unset.
    static func ensureModel() async throws -> URL {
        guard ProcessInfo.processInfo.environment["LIVE_LLAMA"] == "1" else {
            throw XCTSkip("LIVE_LLAMA != 1 — skipping llama live test")
        }
        let file = cacheFile
        if FileManager.default.fileExists(atPath: file.path) { return file }
        let (tmp, _) = try await URLSession.shared.download(from: modelURL)
        try FileManager.default.moveItem(at: tmp, to: file)
        return file
    }
}
