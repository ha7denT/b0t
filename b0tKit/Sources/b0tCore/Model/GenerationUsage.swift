/// A per-turn token-usage snapshot, emitted by `ConversationManager`/`HeartbeatManager`
/// after a turn or beat completes. Drives the crown meters and the Processor
/// Controls token gauge. Snapshot-per-turn (no live streaming) — see
/// `docs/specs/phase-2-stage-d-processor-inspector.md` §5.
public struct GenerationUsage: Sendable, Equatable {
    /// Assembled-prompt tokens (`TokenBudget.estimated`).
    public let tokensIn: Int
    /// Response tokens (`TokenEstimator` over the final response text).
    public let tokensOut: Int
    /// Shared ceiling — the active model's effective budget (`TokenBudget.limit`).
    public let limit: Int
    /// Resolved model id at turn time (empty if unknown).
    public let modelId: String
    /// Per-slot/per-organ subtotals (`TokenBudget.breakdown`).
    public let breakdown: [String: Int]

    public init(
        tokensIn: Int, tokensOut: Int, limit: Int, modelId: String,
        breakdown: [String: Int]
    ) {
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.limit = limit
        self.modelId = modelId
        self.breakdown = breakdown
    }

    public var totalTokens: Int { tokensIn + tokensOut }

    /// Total tokens as a fraction of the ceiling, clamped to `0...1`. Zero when
    /// `limit <= 0`.
    public var fractionUsed: Double {
        guard limit > 0 else { return 0 }
        return min(1.0, Double(totalTokens) / Double(limit))
    }
}
