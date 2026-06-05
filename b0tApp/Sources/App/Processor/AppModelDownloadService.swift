import Foundation
import b0tBrain
import b0tHome
import b0tLlama

/// Production `ModelDownloadServicing` over `b0tLlama.ModelDownloadManager`.
/// One active download at a time is enforced by the coordinator (b0tHome).
final class AppModelDownloadService: ModelDownloadServicing, @unchecked Sendable {
    private let downloads: ModelDownloadManager

    init(downloads: ModelDownloadManager) { self.downloads = downloads }

    func isDownloaded(modelId: String) async -> Bool {
        guard let entry = InferenceModelCatalogue.entry(id: modelId), let file = entry.file
        else { return false }
        return await downloads.isDownloaded(filename: file, expectedSize: entry.sizeBytes)
    }

    func start(modelId: String, progress: @Sendable @escaping (Double) -> Void) async throws {
        guard let entry = InferenceModelCatalogue.entry(id: modelId),
            let file = entry.file, let url = entry.sourceURL,
            let sha = entry.sha256, let size = entry.sizeBytes
        else {
            throw ModelDownloadServiceError.failed(
                message: "that model isn't available to download.")
        }
        do {
            _ = try await downloads.download(
                from: url, filename: file, expectedSHA256: sha, expectedSize: size,
                progress: progress)
        } catch ModelDownloadError.insufficientStorage(let neededBytes, let availableBytes) {
            let gb = Double(neededBytes - availableBytes) / 1_000_000_000
            throw ModelDownloadServiceError.failed(
                message: "not enough room — free up about \(String(format: "%.1f", gb)) GB and try again.")
        } catch ModelDownloadError.checksumMismatch {
            throw ModelDownloadServiceError.failed(
                message: "the download didn\u{2019}t verify. try again.")
        } catch {
            throw ModelDownloadServiceError.failed(
                message: "the download didn\u{2019}t finish. try again.")
        }
    }

    func cancel(modelId: String) async {
        // ModelDownloadManager resumes via HTTP Range on next start; no explicit
        // server-side cancel. The in-flight URLSession task is torn down when the
        // awaiting Task is cancelled by the coordinator. No-op here for v1.
    }

    func storage() async -> (freeBytes: Int, totalBytes: Int) {
        let free =
            ModelDownloadManager.availableCapacityBytes(
                near: ModelDownloadManager.defaultModelsDirectory) ?? 0
        return (free, max(free, 13_000_000_000))
    }
}
