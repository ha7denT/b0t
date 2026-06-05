import XCTest
import b0tBrain

@testable import b0tHome

@MainActor
final class ModelDownloadCoordinatorTests: XCTestCase {
    // @unchecked Sendable: all mutation happens on @MainActor within these tests.
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

    // MARK: - Serial-guard: second concurrent start is a no-op

    /// A controllable fake whose `start` suspends until the test opens the gate,
    /// letting us observe the coordinator's in-flight state from the outside.
    actor Gate {
        private var cont: CheckedContinuation<Void, Never>?
        func wait() async { await withCheckedContinuation { cont = $0 } }
        func open() { cont?.resume(); cont = nil }
    }

    func test_start_isNoOp_whileAnotherDownloadActive() async {
        let gate = Gate()
        // @unchecked Sendable: gate is an actor; no other mutable state is shared.
        final class GatedService: ModelDownloadServicing, @unchecked Sendable {
            let gate: Gate
            init(gate: Gate) { self.gate = gate }
            func isDownloaded(modelId: String) async -> Bool { false }
            func start(modelId: String, progress: @Sendable @escaping (Double) -> Void) async throws {
                await gate.wait()  // stay in-flight until the test opens the gate
            }
            func cancel(modelId: String) async {}
            func storage() async -> (freeBytes: Int, totalBytes: Int) { (0, 0) }
        }

        let coord = ModelDownloadCoordinator(service: GatedService(gate: gate))

        // Launch first download — suspends inside GatedService.start.
        async let first: Void = coord.start(modelId: "qwen3-1.7b")

        // Give the Task scheduler time to reach the gate suspension point
        // and set activeDownloadId before the second call arrives.
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Second start for a different model: must be a no-op.
        await coord.start(modelId: "llama-3.2-1b")

        XCTAssertEqual(
            coord.activeDownloadId, "qwen3-1.7b",
            "activeDownloadId must still point at the first model")
        XCTAssertEqual(
            coord.state(for: "llama-3.2-1b"), .notDownloaded,
            "second model must remain .notDownloaded while first is active")

        // Unblock the first download so the async let can complete cleanly.
        await gate.open()
        await first
    }
}
