import Foundation
import b0tBrain

/// The outcome of one heartbeat tick attempt.
///
/// `.decided` carries the model's TickDecision (already applied by Executor
/// and journaled), the StateDelta the Executor produced, and any
/// `ToolCallRecord`s the model emitted during the tick.
///
/// `.suppressed` indicates the manager declined to call the model — most
/// commonly during quiet hours (Slice 6 Task 24) or when the model was
/// unavailable.
///
/// `.errored` indicates the model call or executor write failed; the manager
/// has logged an error journal entry but hasn't propagated the error to the
/// caller (because heartbeats are best-effort).
public enum TickResult: Sendable, Equatable {
    case decided(decision: TickDecision, delta: StateDelta, toolCalls: [ToolCallRecord])
    case suppressed(reason: SuppressionReason)
    case errored(message: String)
}

public enum SuppressionReason: String, Sendable, Equatable {
    case quietHours
    case modelUnavailable
}
