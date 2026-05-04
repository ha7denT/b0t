import Foundation

public struct ModulesSection: Sendable {
    public let rootURL: URL
    internal let store: BotStore

    public var directoryURL: URL { rootURL.appendingPathComponent("modules", isDirectory: true) }

    public var all: [BotFile] {
        get async throws { try await listMarkdownFiles(at: directoryURL, store: store) }
    }

    public func file(named name: String) async throws -> BotFile {
        try await store.read(directoryURL.appendingPathComponent(name))
    }
}
