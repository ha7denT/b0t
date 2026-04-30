import Foundation

/// A round-trippable view of a single markdown file in a b0t directory.
///
/// `BotFile` is `Sendable` and `Equatable`. It carries `originalText` (the
/// exact bytes read from disk decoded as UTF-8), the parsed `frontmatter`
/// projection, the prose region, and an optional `parseError` annotation.
///
/// Mutations (`settingFrontmatter(_:to:)`, `replacingProse(with:)`, etc.)
/// return new `BotFile` values via surgical splice against `originalText`,
/// preserving comments, whitespace, and key order. See spec §6.
public struct BotFile: Sendable, Equatable {
    public let fileURL: URL
    public let originalText: String
    public let frontmatter: Frontmatter
    public let proseRange: Range<String.Index>
    public let parseError: BotFileError?

    /// Internal entries with byte ranges, used by mutation primitives.
    internal let entries: [FrontmatterParser.Entry]
    /// Range of the frontmatter body bytes (between the `---` delimiters).
    /// Nil when the file has no frontmatter at all.
    internal let frontmatterBodyRange: Range<String.Index>?

    public var prose: String { String(originalText[proseRange]) }
    public var hasFrontmatter: Bool { frontmatterBodyRange != nil }

    /// Parses `text` into a `BotFile`. Returns successfully even when the
    /// file's frontmatter is malformed — `parseError` is annotated and the
    /// whole file body lands in prose.
    public init(fileURL: URL, text: String) throws {
        self.fileURL = fileURL
        self.originalText = text

        let split = try MarkdownSplitter.split(text)

        if let localErr = split.parseError {
            switch localErr {
            case .frontmatterUnterminated:
                self.frontmatterBodyRange = nil
                self.frontmatter = Frontmatter()
                self.entries = []
                self.proseRange = split.proseRange
                self.parseError = .frontmatterUnterminated(fileURL)
                return
            }
        }

        guard let fmRange = split.frontmatterRange else {
            self.frontmatterBodyRange = nil
            self.frontmatter = Frontmatter()
            self.entries = []
            self.proseRange = split.proseRange
            self.parseError = nil
            return
        }

        let fmText = String(text[fmRange])
        do {
            let parsed = try FrontmatterParser.parse(fmText)
            // Translate entry valueRanges from the local fmText into ranges
            // over the *original* text by offset arithmetic.
            let translated = parsed.entries.map { entry -> FrontmatterParser.Entry in
                let lower = relocate(
                    index: entry.valueRange.lowerBound,
                    from: fmText,
                    to: text,
                    offsetBy: fmRange.lowerBound
                )
                let upper = relocate(
                    index: entry.valueRange.upperBound,
                    from: fmText,
                    to: text,
                    offsetBy: fmRange.lowerBound
                )
                return FrontmatterParser.Entry(
                    key: entry.key,
                    valueRange: lower..<upper,
                    parsedValue: entry.parsedValue
                )
            }
            self.frontmatter = parsed.frontmatter
            self.entries = translated
            self.frontmatterBodyRange = fmRange
            self.proseRange = split.proseRange
            self.parseError = nil
        } catch FrontmatterParser.ParseError.invalidYAML(let message) {
            self.frontmatterBodyRange = fmRange
            self.frontmatter = Frontmatter()
            self.entries = []
            self.proseRange = split.proseRange
            self.parseError = .frontmatterInvalidYAML(fileURL, message: message)
        }
    }

    /// Internal initializer used by mutation primitives to build a result
    /// directly from already-computed pieces (avoids re-parsing).
    internal init(
        fileURL: URL,
        originalText: String,
        frontmatter: Frontmatter,
        entries: [FrontmatterParser.Entry],
        frontmatterBodyRange: Range<String.Index>?,
        proseRange: Range<String.Index>,
        parseError: BotFileError?
    ) {
        self.fileURL = fileURL
        self.originalText = originalText
        self.frontmatter = frontmatter
        self.entries = entries
        self.frontmatterBodyRange = frontmatterBodyRange
        self.proseRange = proseRange
        self.parseError = parseError
    }

    public static func == (lhs: BotFile, rhs: BotFile) -> Bool {
        lhs.fileURL == rhs.fileURL
            && lhs.originalText == rhs.originalText
            && lhs.parseError == rhs.parseError
    }
}

// FrontmatterParser.Entry uses Substring.Index which is interchangeable with
// String.Index when the substring shares storage with the source. For our
// translation we re-resolve via offset arithmetic.
private func relocate(
    index: String.Index,
    from sourceText: String,
    to destText: String,
    offsetBy destStart: String.Index
) -> String.Index {
    let offset = sourceText.distance(from: sourceText.startIndex, to: index)
    return destText.index(destStart, offsetBy: offset)
}
