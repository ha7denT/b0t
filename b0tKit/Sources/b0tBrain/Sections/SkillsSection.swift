import Foundation

public struct SkillsSection: Sendable {
    public let rootURL: URL
    internal let store: BotStore

    public var directoryURL: URL { rootURL.appendingPathComponent("skills", isDirectory: true) }

    public var all: [BotFile] {
        get async throws { try await listMarkdownFiles(at: directoryURL, store: store) }
    }

    public func file(named name: String) async throws -> BotFile {
        try await store.read(directoryURL.appendingPathComponent(name))
    }
}
