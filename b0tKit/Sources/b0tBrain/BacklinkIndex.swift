import Foundation

/// A reverse-map cache keyed by (botRoot, latest mtime in tree).
///
/// `BacklinkIndex` is built by walking every markdown file in the bot
/// directory, parsing links, and grouping by resolved target URL. It is
/// recomputed when any file in the tree has a newer mtime than at last
/// computation.
public struct BacklinkIndex: Sendable {
    public let computedAt: Date
    public let highWaterMtime: Date
    private let byTarget: [URL: [BotLink]]

    internal init(computedAt: Date, highWaterMtime: Date, byTarget: [URL: [BotLink]]) {
        self.computedAt = computedAt
        self.highWaterMtime = highWaterMtime
        self.byTarget = byTarget
    }

    public func backlinks(to fileURL: URL) -> [BotLink] {
        byTarget[fileURL.standardizedFileURL] ?? []
    }
}

internal enum BacklinkBuilder {
    /// Walks `botRoot` recursively, parses every `.md` file's prose for
    /// inline links, and returns a fresh `BacklinkIndex`.
    static func build(botRoot: URL, store: BotStore) async throws -> BacklinkIndex {
        let fm = FileManager.default
        guard
            let enumerator = fm.enumerator(
                at: botRoot, includingPropertiesForKeys: [.contentModificationDateKey]
            )
        else {
            return BacklinkIndex(
                computedAt: Date(), highWaterMtime: .distantPast, byTarget: [:]
            )
        }
        let urls: [URL] = enumerator.allObjects.compactMap { $0 as? URL }
        var byTarget: [URL: [BotLink]] = [:]
        var highWater: Date = .distantPast
        for url in urls {
            guard url.pathExtension.lowercased() == "md" else { continue }
            let attrs = (try? fm.attributesOfItem(atPath: url.path)) ?? [:]
            if let m = attrs[.modificationDate] as? Date, m > highWater { highWater = m }
            let file = try await store.read(url)
            for link in BotLink.parse(prose: file.prose, sourceFileURL: url) {
                if case .botFile(let resolved) = link.resolution {
                    byTarget[resolved.standardizedFileURL, default: []].append(link)
                }
                // Missing-target links don't appear in backlinks per spec.
            }
        }
        return BacklinkIndex(
            computedAt: Date(), highWaterMtime: highWater, byTarget: byTarget
        )
    }
}
