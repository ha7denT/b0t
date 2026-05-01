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

    /// Writes a `BotFile` atomically. The file's `originalText` is the source
    /// of truth — the writer doesn't inspect `parseError` because mutations
    /// are no-ops on broken-frontmatter files (BotFile §5.3, spec §6.4).
    ///
    /// The write goes through a sibling temp file (`<name>~`) and an atomic
    /// rename via `FileManager.replaceItem` so a crash mid-write leaves the
    /// original intact.
    ///
    /// For new files (no existing target), the fallback path is
    /// `Data.write(to: temp, .atomic) + FileManager.moveItem` — both steps
    /// individually atomic. The worst-case crash leaves only a sibling
    /// temp file behind, never a partial target.
    public func write(_ file: BotFile) async throws {
        let target = file.fileURL
        let tempURL = target.deletingLastPathComponent()
            .appendingPathComponent(target.lastPathComponent + "~")

        // `replaceItemAt` consumes tempURL on success; this defer is a no-op
        // in that path (try? swallows the not-found). On any failure path it
        // cleans up the orphaned temp.
        defer { try? FileManager.default.removeItem(at: tempURL) }

        do {
            try Data(file.originalText.utf8).write(to: tempURL, options: [.atomic])
            // FileManager.replaceItem requires the destination to exist; if
            // it doesn't, fall back to a plain move.
            if FileManager.default.fileExists(atPath: target.path) {
                _ = try FileManager.default.replaceItemAt(target, withItemAt: tempURL)
            } else {
                try FileManager.default.moveItem(at: tempURL, to: target)
            }
        } catch {
            throw BotFileError.diskWriteFailed(
                target, underlyingDescription: String(describing: error)
            )
        }

        // Update the cache to reflect the new mtime.
        let mtime = try currentMtime(target)
        cache.set(target, file: file, mtime: mtime)
    }

    /// Loads a b0t handle from a directory URL. The directory must exist;
    /// individual files within are read on demand via `Bot`'s sub-namespaces.
    public func load(at directoryURL: URL) async throws -> Bot {
        var isDir: ObjCBool = false
        guard
            FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDir),
            isDir.boolValue
        else {
            throw BotFileError.fileNotFound(directoryURL)
        }
        return Bot(rootURL: directoryURL, store: self)
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
