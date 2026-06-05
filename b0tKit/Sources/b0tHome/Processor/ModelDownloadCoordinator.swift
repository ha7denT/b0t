import Foundation
import Observation
import b0tBrain

/// UI-facing download state for the Processor Directory tab. Owns the observable
/// per-model state; delegates the actual work to an injected `ModelDownloadServicing`.
/// One active download at a time (spec §6).
@MainActor
@Observable
public final class ModelDownloadCoordinator {
    public enum DownloadState: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
        case failed(message: String)
    }

    private let service: any ModelDownloadServicing
    private var states: [String: DownloadState] = [:]
    public private(set) var freeBytes: Int = 0
    public private(set) var totalBytes: Int = 0
    public private(set) var activeDownloadId: String?

    public init(service: any ModelDownloadServicing) {
        self.service = service
    }

    public func state(for modelId: String) -> DownloadState {
        states[modelId] ?? .notDownloaded
    }

    /// Populate state from disk for every downloadable catalogue model + storage.
    public func refresh() async {
        for entry in InferenceModelCatalogue.downloadable {
            guard activeDownloadId != entry.id else { continue }
            let present = await service.isDownloaded(modelId: entry.id)
            states[entry.id] = present ? .downloaded : .notDownloaded
        }
        let s = await service.storage()
        freeBytes = s.freeBytes
        totalBytes = s.totalBytes
    }

    /// Start a download. No-op if another download is active (serial — spec §6).
    public func start(modelId: String) async {
        guard activeDownloadId == nil else { return }
        activeDownloadId = modelId
        states[modelId] = .downloading(progress: 0)
        do {
            try await service.start(modelId: modelId) { [weak self] p in
                Task { @MainActor in
                    guard self?.activeDownloadId == modelId else { return }
                    self?.states[modelId] = .downloading(progress: p)
                }
            }
            states[modelId] = .downloaded
        } catch let ModelDownloadServiceError.failed(message) {
            states[modelId] = .failed(message: message)
        } catch {
            states[modelId] = .failed(message: "the download didn\u{2019}t finish. try again.")
        }
        activeDownloadId = nil
        let s = await service.storage()
        freeBytes = s.freeBytes
        totalBytes = s.totalBytes
    }

    public func cancel(modelId: String) async {
        await service.cancel(modelId: modelId)
        states[modelId] = .notDownloaded
        if activeDownloadId == modelId { activeDownloadId = nil }
    }
}
