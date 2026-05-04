import Foundation

/// Errors raised by `ModuleRegistry.loadModules(for:)` while reading a
/// b0t's `modules/` directory.
///
/// Note: an unknown `module_id` is **not** an error — the registry logs it
/// at debug level and skips the file (spec Q7). Same for `enabled: false`.
/// The errors here represent malformed input the user can fix by editing
/// the markdown.
public enum ModuleLoadError: Error, Sendable {
    /// A module markdown file exists but its frontmatter has no `module_id`
    /// key. The `file` URL points at the offending `.md`.
    case missingModuleID(file: URL)

    /// The module's `Parameters` schema rejected the frontmatter. The
    /// `moduleID` is the `module_id` we recognised; `underlying` is the
    /// per-Module decoder's specific error (e.g. wrong key type, missing
    /// required field).
    case invalidParameters(moduleID: String, underlying: any Error)
}
