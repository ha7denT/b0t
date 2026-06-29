import Foundation

/// First-launch bootstrap. Idempotent.
///
/// Copies the bundled `default-bot/` content into `<documents>/b0ts/b0t-01/`
/// the first time it runs, and writes the `_active` pointer file naming
/// `b0t-01` as the active bot. Subsequent calls are no-ops as long as the
/// pointed-at directory exists.
public enum BotProvisioner {
    /// Convenience overload that resolves `default-bot/` from the given
    /// bundle. The bundle must contain a folder reference named `default-bot`.
    public static func ensureDefaultBotProvisioned(
        documentsURL: URL,
        bundle: Bundle = .main
    ) throws -> URL {
        guard let source = bundle.url(forResource: "default-bot", withExtension: nil) else {
            throw BotFileError.fileNotFound(
                documentsURL.appendingPathComponent("default-bot")
            )
        }
        return try ensureDefaultBotProvisioned(
            documentsURL: documentsURL,
            defaultBotSourceURL: source
        )
    }

    /// Test-friendly entry point that takes the source directory directly.
    public static func ensureDefaultBotProvisioned(
        documentsURL: URL,
        defaultBotSourceURL: URL
    ) throws -> URL {
        let fm = FileManager.default
        let b0ts = documentsURL.appendingPathComponent("b0ts", isDirectory: true)
        let activePtr = b0ts.appendingPathComponent("_active")

        // Step 1: existing _active pointing at an existing dir → sync + return it.
        if let name = (try? String(contentsOf: activePtr, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !name.isEmpty
        {
            let candidate = b0ts.appendingPathComponent(name, isDirectory: true)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue {
                let added = try syncMissingFiles(from: defaultBotSourceURL, into: candidate)
                #if DEBUG
                    if added > 0 { print("[b0t] provisioner synced \(added) new bundled file(s)") }
                #endif
                return candidate
            }
            // Else fall through to fresh provision.
        }

        // Step 2: provision b0t-01 from the bundled source.
        try fm.createDirectory(at: b0ts, withIntermediateDirectories: true)
        let target = b0ts.appendingPathComponent("b0t-01", isDirectory: true)
        if !fm.fileExists(atPath: target.path) {
            try fm.copyItem(at: defaultBotSourceURL, to: target)
        }

        // Step 3: write _active pointing at b0t-01.
        try "b0t-01\n".write(to: activePtr, atomically: true, encoding: .utf8)
        return target
    }

    /// Copies any bundled file missing from `botDir` into it, creating
    /// intermediate directories. NEVER overwrites an existing file (preserves
    /// user edits). Returns the number of files added. Hidden files are skipped.
    ///
    /// Additive only: a bundled file whose content changed upstream is not
    /// re-copied if the user already has any version of it. A file the user
    /// deleted will reappear (accepted trade-off — see the bundle-sync plan).
    @discardableResult
    static func syncMissingFiles(from bundledRoot: URL, into botDir: URL) throws -> Int {
        let fm = FileManager.default
        // Resolve symlinks on bundledRoot so its component count matches the
        // fully-resolved URLs that the enumerator returns (on macOS /var is a
        // symlink to /private/var; the enumerator always returns /private/var/…).
        let resolvedRoot = bundledRoot.resolvingSymlinksInPath()
        guard
            let enumerator = fm.enumerator(
                at: resolvedRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles])
        else { return 0 }

        let rootComponentCount = resolvedRoot.pathComponents.count
        var added = 0
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            // Resolve the enumerated URL to the same symlink basis as resolvedRoot
            // before computing the relative path components.
            let resolvedFile = fileURL.resolvingSymlinksInPath()
            let relativeComponents = Array(
                resolvedFile.pathComponents.dropFirst(rootComponentCount))
            let target = relativeComponents.reduce(botDir) { $0.appendingPathComponent($1) }
            if !fm.fileExists(atPath: target.path) {
                try fm.createDirectory(
                    at: target.deletingLastPathComponent(),
                    withIntermediateDirectories: true)
                try fm.copyItem(at: fileURL, to: target)
                added += 1
            }
        }
        return added
    }

    /// Reads the starter `BotModel` from `manufacturers.json` in the given bundle,
    /// if present and well-formed. Returns `nil` if the file is absent or
    /// undecodable — callers fall back to whatever defaults the bundled
    /// `default-bot/` already ships with.
    ///
    /// Phase 4 ships only Hilfer (Wundercog tier-1 starter); the bundled
    /// `default-bot/` markdown is already shaped for Hilfer, so this helper is
    /// purely informational in v1 (logs the active starter Model). Phase 6+
    /// expansions will use the returned Model's `defaultModules` /
    /// `defaultTools` / `defaultPersonalityDir` to drive variant provisioning.
    public static func starterDefaultsFromCatalogue(bundle: Bundle = .main) -> BotModel? {
        guard let url = bundle.url(forResource: "manufacturers", withExtension: "json") else {
            return nil
        }
        return try? ManufacturerCatalogue.load(from: url).starterModel()
    }
}
