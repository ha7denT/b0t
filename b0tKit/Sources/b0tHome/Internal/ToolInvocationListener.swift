@preconcurrency import Combine
import Foundation
import b0tFace

/// Bridges b0tCore's tool-call events to the anatomy's wiring network.
/// On each invocation, marks the relevant organ in `state.activeWiring` for ~2s,
/// then removes it. Multiple concurrent invocations are tracked correctly via
/// the underlying Set.
///
/// Routing: tool names with the `memory.` prefix go to the Memory organ;
/// everything else routes through the Tools organ. Future refinement could
/// add `sensors.*` etc.
@MainActor
public final class ToolInvocationListener {
    let state: AnatomyState
    let source: AnyPublisher<String, Never>
    private var cancellable: AnyCancellable?

    public init(state: AnatomyState, source: AnyPublisher<String, Never>) {
        self.state = state
        self.source = source
    }

    public func start() {
        // The manager publishes from its `actor` executor (off-main). This type
        // is `@MainActor`, so its `.sink` closure is main-actor-isolated and
        // would TRAP if invoked off-main (the on-device "freeze"/kill, 2026-06-29).
        // `.receive(on: .main)` guarantees delivery on the main run loop.
        cancellable =
            source
            .receive(on: DispatchQueue.main)
            .sink { [weak self] toolName in
                self?.pulse(for: toolName)
            }
    }

    public func stop() {
        cancellable?.cancel()
        cancellable = nil
    }

    private func pulse(for toolName: String) {
        let organ = organID(for: toolName)
        state.activeWiring.insert(organ)
        Task { [weak state] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            state?.activeWiring.remove(organ)
        }
    }

    private func organID(for toolName: String) -> OrganID {
        if toolName.hasPrefix("memory.") { return .memory }
        return .tools
    }
}
