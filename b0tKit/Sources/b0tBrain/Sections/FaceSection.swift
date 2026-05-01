import Foundation

public struct FaceSection: Sendable {
    public let rootURL: URL
    internal let store: BotStore

    public var directoryURL: URL { rootURL.appendingPathComponent("face", isDirectory: true) }

    public var all: [BotFile] {
        get async throws { try await listMarkdownFiles(at: directoryURL, store: store) }
    }
}
