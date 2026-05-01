import Foundation

/// A handle to an on-disk b0t directory. Cheap to construct; access goes
/// through `BotStore` (the actor that owns I/O and the cache).
///
/// `Bot` is `Sendable`. Section sub-namespaces are likewise `Sendable`
/// structs that know their canonical sub-directory paths.
public struct Bot: Sendable {
    public let rootURL: URL
    internal let store: BotStore

    public var identity: IdentitySection { IdentitySection(rootURL: rootURL, store: store) }
    public var memory: MemorySection { MemorySection(rootURL: rootURL, store: store) }
    public var skills: SkillsSection { SkillsSection(rootURL: rootURL, store: store) }
    public var heartbeat: HeartbeatSection { HeartbeatSection(rootURL: rootURL, store: store) }
    public var face: FaceSection { FaceSection(rootURL: rootURL, store: store) }
    public var journal: JournalSection { JournalSection(rootURL: rootURL, store: store) }
}

/// Shared helper: enumerate `.md` files in a directory, read them through
/// the store. Used by sections that present an "all files in this dir" view.
internal func listMarkdownFiles(at directoryURL: URL, store: BotStore) async throws -> [BotFile] {
    let fm = FileManager.default
    guard fm.fileExists(atPath: directoryURL.path) else { return [] }
    let names = try fm.contentsOfDirectory(atPath: directoryURL.path)
        .filter { $0.lowercased().hasSuffix(".md") }
        .sorted()
    var files: [BotFile] = []
    for name in names {
        let url = directoryURL.appendingPathComponent(name)
        files.append(try await store.read(url))
    }
    return files
}
