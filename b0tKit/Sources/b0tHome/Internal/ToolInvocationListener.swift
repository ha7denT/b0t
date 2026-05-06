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
        cancellable = source.sink { [weak self] toolName in
            // PassthroughSubject delivers synchronously on the calling queue.
            // In production HomeView wires the subscription on MainActor, so
            // this fires on MainActor. Tests are @MainActor classes — same.
            MainActor.assumeIsolated {
                self?.pulse(for: toolName)
            }
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
