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

        // Step 1: existing _active pointing at an existing dir → return it.
        if let name = (try? String(contentsOf: activePtr, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !name.isEmpty
        {
            let candidate = b0ts.appendingPathComponent(name, isDirectory: true)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue {
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
}
