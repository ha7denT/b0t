import Foundation
import OSLog
#if canImport(BackgroundTasks)
    import BackgroundTasks
#endif

/// The seam through which `HeartbeatManager` schedules background ticks.
///
/// `LiveBGTaskScheduler` wraps `BGTaskScheduler.shared` and submits
/// `BGAppRefreshTaskRequest`s. `FakeHeartbeatScheduler` (test-target visible)
/// records calls without actually scheduling anything, so unit tests can
/// assert on the schedule-next arithmetic without depending on iOS background
/// behaviour.
public protocol HeartbeatScheduler: Sendable {
    /// Submit a request that the OS wake the app no earlier than `earliestBeginDate`.
    /// The OS may delay further or skip entirely — that's not an error.
    func submitNextRequest(earliestBeginDate: Date) async throws
}

public struct LiveBGTaskScheduler: HeartbeatScheduler {
    public static let taskIdentifier = "com.b0t.heartbeat"

    private static let logger = Logger(
        subsystem: "com.toppeross.b0t.b0tCore", category: "LiveBGTaskScheduler")

    public init() {}

    public func submitNextRequest(earliestBeginDate: Date) async throws {
        #if canImport(BackgroundTasks) && os(iOS)
            let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
            request.earliestBeginDate = earliestBeginDate
            do {
                try BGTaskScheduler.shared.submit(request)
                Self.logger.debug("submitted BG task request: \(earliestBeginDate.description)")
            } catch {
                Self.logger.error(
                    "BGTaskScheduler.submit failed: \(String(describing: error))")
                throw error
            }
        #else
            _ = earliestBeginDate
        #endif
    }
}

#if DEBUG
    public final class FakeHeartbeatScheduler: HeartbeatScheduler, @unchecked Sendable {
        public private(set) var submittedDates: [Date] = []
        public init() {}
        public func submitNextRequest(earliestBeginDate: Date) async throws {
            submittedDates.append(earliestBeginDate)
        }
    }
#endif
