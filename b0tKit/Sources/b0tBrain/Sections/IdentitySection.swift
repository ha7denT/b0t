import Foundation

public struct IdentitySection: Sendable {
    public let rootURL: URL
    internal let store: BotStore

    public var directoryURL: URL { rootURL.appendingPathComponent("identity", isDirectory: true) }
    public var coreURL: URL { directoryURL.appendingPathComponent("core.md") }
    public var principlesURL: URL { directoryURL.appendingPathComponent("principles.md") }
    public var aboutURL: URL { directoryURL.appendingPathComponent("about_b0t.md") }
    public var appearanceURL: URL { directoryURL.appendingPathComponent("appearance.md") }
    public var audioURL: URL { directoryURL.appendingPathComponent("audio.md") }
    public var processorURL: URL { directoryURL.appendingPathComponent("processor.md") }

    public var core: BotFile { get async throws { try await store.read(coreURL) } }
    public var principles: BotFile { get async throws { try await store.read(principlesURL) } }
    public var about: BotFile { get async throws { try await store.read(aboutURL) } }
    public var appearance: BotFile { get async throws { try await store.read(appearanceURL) } }
    public var audio: BotFile { get async throws { try await store.read(audioURL) } }
    public var processor: BotFile { get async throws { try await store.read(processorURL) } }
}
