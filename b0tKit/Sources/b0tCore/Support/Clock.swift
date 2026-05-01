import Foundation

/// A small abstraction over time for tests.
///
/// `SystemClock` reads the wall clock. `TestClock` (test-target only) returns
/// a fixed `Date` configured per test. Used by `ConversationManager`,
/// `HeartbeatManager`, `JournalWriter`, `MissedBeatDetector`, and
/// `TimeAwarenessTool` so deterministic timestamps are possible in tests.
public protocol Clock: Sendable {
    func now() -> Date
}

public struct SystemClock: Clock {
    public init() {}
    public func now() -> Date { Date() }
}
