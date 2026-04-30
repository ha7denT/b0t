import Foundation

internal struct MarkdownSplitResult {
    let frontmatterRange: Range<String.Index>?
    let proseRange: Range<String.Index>
    let parseError: BotFileLocalParseError?
}

/// A subset of `BotFileError` produced at the splitter layer. `BotStore.read`
/// converts these to fully-qualified `BotFileError` cases that include the
/// file URL.
internal enum BotFileLocalParseError: Equatable {
    case frontmatterUnterminated
}

internal enum MarkdownSplitter {
    /// Splits `text` into a frontmatter region and a prose region.
    ///
    /// A leading UTF-8 BOM (U+FEFF) is tolerated and treated as if absent.
    /// The frontmatter region is the bytes strictly between the opening
    /// `---\n` and the closing `\n---` (or `\n---\n` / `\n---` at EOF).
    static func split(_ text: String) throws -> MarkdownSplitResult {
        let stripped: Substring = {
            if text.first == "\u{FEFF}" { return text.dropFirst() }
            return Substring(text)
        }()

        // Must start with `---` followed by newline (or be the entire file).
        let opener = "---\n"
        guard stripped.hasPrefix(opener) else {
            return MarkdownSplitResult(
                frontmatterRange: nil,
                proseRange: text.startIndex..<text.endIndex,
                parseError: nil
            )
        }

        let bodyStart = stripped.index(stripped.startIndex, offsetBy: opener.count)

        // Empty-frontmatter case: closing `---` immediately follows the opener
        // (e.g. `---\n---\n` or `---\n---`).
        let bodyRest = stripped[bodyStart...]
        if bodyRest.hasPrefix("---\n") || bodyRest == "---" {
            let fmStart = mapIndex(bodyStart, from: stripped, to: text)
            let proseStart: String.Index = {
                if bodyRest == "---" {
                    return mapIndex(stripped.endIndex, from: stripped, to: text)
                }
                let after = stripped.index(bodyStart, offsetBy: "---\n".count)
                return mapIndex(after, from: stripped, to: text)
            }()
            return MarkdownSplitResult(
                frontmatterRange: fmStart..<fmStart,
                proseRange: proseStart..<text.endIndex,
                parseError: nil
            )
        }

        // Search for `\n---` followed by either `\n` or end-of-string.
        let closingPattern = "\n---"
        var searchStart = bodyStart
        while searchStart < stripped.endIndex {
            guard
                let closeRange = stripped.range(
                    of: closingPattern, range: searchStart..<stripped.endIndex)
            else {
                // No closing delimiter — soft fail.
                return MarkdownSplitResult(
                    frontmatterRange: nil,
                    proseRange: text.startIndex..<text.endIndex,
                    parseError: .frontmatterUnterminated
                )
            }
            let after = closeRange.upperBound
            if after == stripped.endIndex || stripped[after] == "\n" {
                // Map indices from `stripped` back to `text` (BOM-aware).
                let fmStart = mapIndex(bodyStart, from: stripped, to: text)
                let fmEnd = mapIndex(closeRange.lowerBound, from: stripped, to: text)
                let proseStart: String.Index = {
                    let afterClose = stripped.index(after: closeRange.upperBound)
                    return after == stripped.endIndex
                        ? mapIndex(stripped.endIndex, from: stripped, to: text)
                        : mapIndex(afterClose, from: stripped, to: text)
                }()
                // The frontmatter region is the body strictly between delimiters.
                // We trim a single trailing newline if the body ends with one,
                // so callers see the YAML content without the closing `\n`.
                let trimmedEnd = trimTrailingNewline(in: text, range: fmStart..<fmEnd)
                return MarkdownSplitResult(
                    frontmatterRange: fmStart..<trimmedEnd,
                    proseRange: proseStart..<text.endIndex,
                    parseError: nil
                )
            }
            // Found `\n---` followed by something other than newline (e.g.
            // `---x`). Skip past and keep searching.
            searchStart = stripped.index(after: closeRange.lowerBound)
        }

        return MarkdownSplitResult(
            frontmatterRange: nil,
            proseRange: text.startIndex..<text.endIndex,
            parseError: .frontmatterUnterminated
        )
    }

    private static func mapIndex(
        _ idx: Substring.Index,
        from sub: Substring,
        to text: String
    ) -> String.Index {
        let offset = sub.distance(from: sub.startIndex, to: idx)
        let prefix = text.distance(from: text.startIndex, to: sub.startIndex)
        return text.index(text.startIndex, offsetBy: prefix + offset)
    }

    private static func trimTrailingNewline(
        in text: String,
        range: Range<String.Index>
    ) -> String.Index {
        guard range.lowerBound < range.upperBound else { return range.upperBound }
        let beforeEnd = text.index(before: range.upperBound)
        return text[beforeEnd] == "\n" ? beforeEnd : range.upperBound
    }
}
