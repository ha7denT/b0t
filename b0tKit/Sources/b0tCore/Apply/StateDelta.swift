import Foundation

/// A record of what changed on disk during one Executor run.
///
/// `writtenFiles` is the set of file URLs the Executor mutated — used by
/// JournalWriter to populate the `state_delta` field of OpenClaw entries.
///
/// `wouldNotifyText` is set when the model's decision is interpreted as
/// user-facing intent (e.g., a heartbeat tick that "decided: notify_user").
/// Phase 2 does NOT post real notifications via UNUserNotificationCenter —
/// Phase 4+ wires that. Until then, `wouldNotifyText` is captured and
/// journaled for inspection.
public struct StateDelta: Sendable, Equatable {
    public let writtenFiles: Set<URL>
    public let wouldNotifyText: String?

    public init(writtenFiles: Set<URL> = [], wouldNotifyText: String? = nil) {
        self.writtenFiles = writtenFiles
        self.wouldNotifyText = wouldNotifyText
    }

    public static let empty = StateDelta()
}
