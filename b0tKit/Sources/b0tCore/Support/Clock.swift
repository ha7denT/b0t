import Foundation

/// A small abstraction over time for tests.
///
/// `SystemClock` reads the wall clock. `TestClock` (test-target only) returns
/// a fixed `Date` configured per test. Used by `ConversationManager`,
/// `HeartbeatManager`, `JournalWriter`, `MissedBeatDetector`, and
/// `TimeAwarenessTool` (now in `b0tModules`) so deterministic timestamps are possible in tests.
///
/// Note: distinct from Swift's standard library `Clock` protocol (the one
/// used with `ContinuousClock` / `SuspendingClock`). This is a small
/// `Date`-returning protocol scoped to b0tCore. Consumers inside the module
/// reference `b0tCore.Clock` by default; outside callers may need to qualify
/// the name if they also import `_Concurrency`.
public protocol Clock: Sendable {
    func now() -> Date
}

public struct SystemClock: Clock {
    public init() {}
    public func now() -> Date { Date() }
}
