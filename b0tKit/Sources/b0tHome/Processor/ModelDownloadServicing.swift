import Foundation

/// Error surfaced by a download backend, already voice-guide-worded by the conformer.
public enum ModelDownloadServiceError: Error, Sendable, Equatable {
    case failed(message: String)
}

/// Async backend seam for model downloads. Implemented in `b0tApp` over
/// `b0tLlama.ModelDownloadManager`; kept abstract here so `b0tHome` (and its
/// host tests) never link the llama binary. Spec §6.
public protocol ModelDownloadServicing: AnyObject, Sendable {
    func isDownloaded(modelId: String) async -> Bool
    func start(modelId: String, progress: @Sendable @escaping (Double) -> Void) async throws
    func cancel(modelId: String) async
    func storage() async -> (freeBytes: Int, totalBytes: Int)
}
