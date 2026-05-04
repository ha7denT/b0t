import Foundation
import FoundationModels

/// A tool the model can call to anchor its replies in current time.
///
/// Returns an ISO-8601 timestamp (UTC) and a coarse morning/afternoon/evening/
/// night bucket. Trivially deterministic given a fixed clock, exercising the
/// @Generable + Tool wiring before Phase 3 lands real module bridges.
///
/// Note: `Tool` in the iOS 26 SDK declares `name` and `description` as instance
/// properties (`var name: String { get }`), not static. The spec's `static let`
/// form fails conformance; adapted to `let` instance properties here.
public struct TimeAwarenessTool: Tool, Sendable {
    public let name = "time_awareness"
    public let description =
        "Returns current local time and a coarse morning/afternoon/evening/night bucket."

    @Generable
    public struct Arguments: Sendable {
        public init() {}
    }

    @Generable
    public struct Output: Sendable, Equatable {
        @Guide(description: "ISO-8601 timestamp in UTC.")
        public let isoTimestamp: String
        @Guide(description: "Coarse time-of-day bucket.")
        public let timeOfDay: TimeOfDay

        public init(isoTimestamp: String, timeOfDay: TimeOfDay) {
            self.isoTimestamp = isoTimestamp
            self.timeOfDay = timeOfDay
        }
    }

    private let clock: any Clock

    public init(clock: any Clock = SystemClock()) {
        self.clock = clock
    }

    public func call(arguments: Arguments) async throws -> Output {
        let now = clock.now()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return Output(
            isoTimestamp: formatter.string(from: now),
            timeOfDay: TimeOfDay.bucket(for: now)
        )
    }
}
