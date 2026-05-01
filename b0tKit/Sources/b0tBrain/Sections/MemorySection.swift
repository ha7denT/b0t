import Foundation

public struct MemorySection: Sendable {
    public let rootURL: URL
    internal let store: BotStore

    public var directoryURL: URL { rootURL.appendingPathComponent("memory", isDirectory: true) }
    public var coreURL: URL { directoryURL.appendingPathComponent("core.md") }
    public var aboutMeURL: URL { directoryURL.appendingPathComponent("about_me.md") }
    public var recentURL: URL { directoryURL.appendingPathComponent("recent.md") }
    public var relationshipsURL: URL { directoryURL.appendingPathComponent("relationships.md") }
    public var archiveDirectoryURL: URL {
        directoryURL.appendingPathComponent("archive", isDirectory: true)
    }

    public var core: BotFile { get async throws { try await store.read(coreURL) } }
    public var aboutMe: BotFile { get async throws { try await store.read(aboutMeURL) } }
    public var recent: BotFile { get async throws { try await store.read(recentURL) } }
    public var relationships: BotFile {
        get async throws { try await store.read(relationshipsURL) }
    }

    public var archive: [BotFile] {
        get async throws {
            try await listMarkdownFiles(at: archiveDirectoryURL, store: store)
        }
    }
}
