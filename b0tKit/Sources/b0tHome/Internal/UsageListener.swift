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
        // The manager publishes from its `actor` executor (off-main). This type
        // is `@MainActor`, so its `.sink` closure is main-actor-isolated and
        // would TRAP if invoked off-main (the on-device "freeze"/kill, 2026-06-29).
        // `.receive(on: .main)` guarantees delivery on the main run loop, so the
        // isolated closure runs where it's allowed.
        cancellable =
            source
            .receive(on: DispatchQueue.main)
            .sink { [weak self] usage in
                self?.state.latestUsage = usage
            }
    }

    public func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}
