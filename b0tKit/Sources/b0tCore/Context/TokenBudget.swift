import Foundation

/// A debug record of how the prompt's token budget was spent.
///
/// `estimated` is the assembler's pre-call estimate (Apple's tokenizer if
/// available, else 4-chars-per-token heuristic). `limit` is the configured
/// hard limit (typically 3500 — leaves ~500 tokens for the response, ~500
/// for the runtime's own overhead). `breakdown` is the per-section count so
/// DEBUG logs can identify which file pushed the prompt over.
///
/// `didFallBackToDigest` is set by `ContextAssembler` when the graduated
/// fallback (spec §7.4) had to drop content to fit. Writes to the journal
/// as part of the tick entry's `state_delta` for transparency.
public struct TokenBudget: Sendable, Equatable {
    public let estimated: Int
    public let limit: Int
    public let breakdown: [String: Int]
    public let didFallBackToDigest: Bool

    public init(
        estimated: Int,
        limit: Int,
        breakdown: [String: Int],
        didFallBackToDigest: Bool
    ) {
        self.estimated = estimated
        self.limit = limit
        self.breakdown = breakdown
        self.didFallBackToDigest = didFallBackToDigest
    }

    public var fitsWithinLimit: Bool { estimated <= limit }
}
