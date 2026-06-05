import XCTest
import b0tBrain

@testable import b0tHome

@MainActor
final class ModelDownloadCoordinatorTests: XCTestCase {
    final class FakeService: ModelDownloadServicing, @unchecked Sendable {
        var downloaded: Set<String> = []
        var shouldFail = false
        func isDownloaded(modelId: String) async -> Bool { downloaded.contains(modelId) }
        func start(modelId: String, progress: @Sendable @escaping (Double) -> Void) async throws {
            progress(0.5)
            if shouldFail { throw ModelDownloadServiceError.failed(message: "boom") }
            progress(1.0)
            downloaded.insert(modelId)
        }
        func cancel(modelId: String) async {}
        func storage() async -> (freeBytes: Int, totalBytes: Int) { (5_000_000_000, 13_000_000_000) }
    }

    func test_refresh_marksDownloadedModels() async {
        let svc = FakeService(); svc.downloaded = ["qwen3-1.7b"]
        let coord = ModelDownloadCoordinator(service: svc)
        await coord.refresh()
        XCTAssertEqual(coord.state(for: "qwen3-1.7b"), .downloaded)
        XCTAssertEqual(coord.state(for: "llama-3.2-1b"), .notDownloaded)
    }

    func test_start_movesToDownloadedOnSuccess() async {
        let coord = ModelDownloadCoordinator(service: FakeService())
        await coord.start(modelId: "qwen3-1.7b")
        XCTAssertEqual(coord.state(for: "qwen3-1.7b"), .downloaded)
    }

    func test_start_movesToFailedOnError() async {
        let svc = FakeService(); svc.shouldFail = true
        let coord = ModelDownloadCoordinator(service: svc)
        await coord.start(modelId: "qwen3-1.7b")
        if case .failed = coord.state(for: "qwen3-1.7b") {} else { XCTFail("expected failed") }
    }
}
