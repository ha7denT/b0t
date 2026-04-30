import Foundation

/// The single I/O actor for the brain layer. Owns an `MtimeStampedCache`
/// and is the only thing that touches the file system for reads/writes.
public actor BotStore {
    private let cache: MtimeStampedCache

    public init() {
        self.cache = MtimeStampedCache()
    }

    /// Reads a single file, parses it, and returns a `BotFile`.
    ///
    /// Throws `BotFileError.fileNotFound` if the file does not exist on
    /// disk, or `BotFileError.notUTF8` if its bytes cannot be decoded as
    /// UTF-8. Frontmatter parse problems are *annotated* on the returned
    /// `BotFile.parseError` (soft fail).
    public func read(_ fileURL: URL) async throws -> BotFile {
        let mtime = try currentMtime(fileURL)

        if let (cached, cachedMtime) = cache.get(fileURL), cachedMtime == mtime {
            return cached
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw BotFileError.fileNotFound(fileURL)
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw BotFileError.notUTF8(fileURL)
        }

        let file = try BotFile(fileURL: fileURL, text: text)
        cache.set(fileURL, file: file, mtime: mtime)
        return file
    }

    /// Manually invalidate a cached file. Use sparingly; mtime checks
    /// handle the common case automatically.
    public func invalidate(_ fileURL: URL) {
        cache.invalidate(fileURL)
    }

    /// Drop every cached entry.
    public func invalidateAll() {
        cache.invalidateAll()
    }

    private func currentMtime(_ fileURL: URL) throws -> Date {
        let attrs: [FileAttributeKey: Any]
        do {
            attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        } catch {
            throw BotFileError.fileNotFound(fileURL)
        }
        guard let mtime = attrs[.modificationDate] as? Date else {
            throw BotFileError.fileNotFound(fileURL)
        }
        return mtime
    }
}
