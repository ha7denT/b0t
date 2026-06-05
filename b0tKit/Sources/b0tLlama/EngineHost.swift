import Foundation
import b0tBrain
import b0tCore
import os

/// A swappable `InferenceEngine`. The live managers hold this stable reference;
/// the inner engine swaps on model change so the managers never rebuild.
/// Approach A of `docs/specs/phase-2-stage-d-processor-inspector.md` §4.
///
/// A `final class` (not an actor) so `contextWindow`/`activeModelId` can be the
/// synchronous, `nonisolated` reads `InferenceEngine` requires. The lock guards
/// only reference reads/swaps; it is never held across `await`.
public final class EngineHost: InferenceEngine, @unchecked Sendable {
    /// Loads a concrete engine for a catalogue id, returning it with its context
    /// window, or `nil` when the model isn't present. Injected so this type stays
    /// testable without the llama binary; production passes a `ModelStore`-backed
    /// loader (see `makeProductionLoader`).
    public typealias Loader = @Sendable (_ modelId: String) async -> (any InferenceEngine, Int)?

    private let lock = OSAllocatedUnfairLock<State>(
        initialState: State(engine: nil, modelId: "", window: 4096))
    private struct State {
        var engine: (any InferenceEngine)?
        var modelId: String
        var window: Int
    }
    private let loader: Loader

    public init(initialEngine: any InferenceEngine, initialModelId: String, loader: @escaping Loader) {
        self.loader = loader
        lock.withLock {
            $0.engine = initialEngine
            $0.modelId = initialModelId
            $0.window = initialEngine.contextWindow
        }
    }

    public var contextWindow: Int { lock.withLock { $0.window } }
    public var activeModelId: String { lock.withLock { $0.modelId } }

    private var currentEngine: any InferenceEngine {
        lock.withLock { $0.engine } ?? FallbackEngine()
    }

    public func generate<Output: StructuredOutput>(
        context: AssembledContext, generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord]) {
        try await currentEngine.generate(context: context, generating: outputType)
    }

    /// Swap the live engine to `id`. Loads via the injected loader; on success
    /// swaps the inner engine + window; on absence returns `.missing` and leaves
    /// the current engine intact.
    public func selectModel(id: String) async -> ModelSelectionOutcome {
        guard let (engine, window) = await loader(id) else {
            return .missing(modelId: id)
        }
        lock.withLock {
            $0.engine = engine
            $0.modelId = id
            $0.window = window
        }
        return .active(modelId: id)
    }
}

/// Inert engine used only if the host is somehow queried before init populates it.
private struct FallbackEngine: InferenceEngine {
    var contextWindow: Int { 4096 }
    func generate<Output: StructuredOutput>(
        context: AssembledContext, generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord]) {
        throw InferenceEngineError.modelUnavailable
    }
}
