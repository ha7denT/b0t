import Foundation

/// Errors produced by the brain layer.
///
/// Read-side cases divide into two groups by the spec:
/// - `.fileNotFound` and `.notUTF8` are *thrown* by `BotStore.read` because
///   no `BotFile` value can be constructed without bytes-decoded-as-UTF-8.
/// - `.frontmatterUnterminated` and `.frontmatterInvalidYAML` are *annotated*
///   on the resulting `BotFile.parseError` — the prose is still readable.
///
/// Write-side cases (`.cannotMutateBrokenFrontmatter`, `.diskWriteFailed`)
/// are always thrown.
public enum BotFileError: Error, Sendable, Equatable {
    case fileNotFound(URL)
    case notUTF8(URL)
    case frontmatterUnterminated(URL)
    case frontmatterInvalidYAML(URL, message: String)
    case cannotMutateBrokenFrontmatter(URL)
    case diskWriteFailed(URL, underlyingDescription: String)
}
