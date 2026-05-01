import Foundation

public struct HeartbeatSection: Sendable {
    public let rootURL: URL
    internal let store: BotStore

    public var directoryURL: URL { rootURL.appendingPathComponent("heartbeat", isDirectory: true) }
    public var scheduleURL: URL { directoryURL.appendingPathComponent("schedule.md") }
    public var actionsURL: URL { directoryURL.appendingPathComponent("actions.md") }

    public var schedule: BotFile { get async throws { try await store.read(scheduleURL) } }
    public var actions: BotFile { get async throws { try await store.read(actionsURL) } }
}
