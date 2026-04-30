import Foundation

/// A small wrapper around `NSCache<NSURL, CacheBox>` that pairs each cached
/// `BotFile` with the file's mtime at the time of caching. Used by
/// `BotStore` to invalidate entries when the on-disk mtime changes.
///
/// `NSCache` is itself thread-safe (Apple-documented). The cache is only
/// ever accessed from inside `BotStore`'s actor isolation, so the
/// `@unchecked Sendable` on `MtimeStampedCache` is contained — it never escapes.
internal final class MtimeStampedCache: @unchecked Sendable {
    private let storage = NSCache<NSURL, CacheBox>()

    func get(_ url: URL) -> (BotFile, Date)? {
        guard let box = storage.object(forKey: url as NSURL) else { return nil }
        return (box.file, box.mtime)
    }

    func set(_ url: URL, file: BotFile, mtime: Date) {
        storage.setObject(CacheBox(file: file, mtime: mtime), forKey: url as NSURL)
    }

    func invalidate(_ url: URL) {
        storage.removeObject(forKey: url as NSURL)
    }

    func invalidateAll() {
        storage.removeAllObjects()
    }

    private final class CacheBox {
        let file: BotFile
        let mtime: Date
        init(file: BotFile, mtime: Date) {
            self.file = file
            self.mtime = mtime
        }
    }
}
