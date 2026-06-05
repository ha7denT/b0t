@preconcurrency import Combine
import Foundation
import b0tCore

/// Bridges a manager's `usageEvents` to `AnatomyState.latestUsage`. Mirrors
/// `ToolInvocationListener`. PassthroughSubject delivers synchronously on the
/// calling queue; production wires this on MainActor.
@MainActor
public final class UsageListener {
    let state: AnatomyState
    let source: AnyPublisher<GenerationUsage, Never>
    private var cancellable: AnyCancellable?

    public init(state: AnatomyState, source: AnyPublisher<GenerationUsage, Never>) {
        self.state = state
        self.source = source
    }

    public func start() {
        cancellable = source.sink { [weak self] usage in
            // PassthroughSubject delivers synchronously on the calling queue.
            // In production HomeView wires the subscription on MainActor, so
            // this fires on MainActor. Tests are @MainActor classes — same.
            MainActor.assumeIsolated {
                self?.state.latestUsage = usage
            }
        }
    }

    public func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}
