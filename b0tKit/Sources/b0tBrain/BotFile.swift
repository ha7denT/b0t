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

extension BotFile {
    /// Sets a frontmatter key to a new value. If the key exists, its value
    /// text is surgically replaced. If not, a new line is appended directly
    /// before the closing `---`.
    ///
    /// On a file with `parseError == .frontmatterInvalidYAML(_)`, this is a
    /// no-op — we cannot surgically splice without a trustworthy parse.
    public func settingFrontmatter(_ key: String, to value: YAMLValue) -> BotFile {
        if case .frontmatterInvalidYAML = parseError { return self }

        // No-op short-circuit: if the value already equals the parsed value of the
        // existing entry, return self unchanged. This honours spec §6.5(3) for
        // list values, multi-line literals, and entries with end-of-line comments
        // — all of which would lossy-re-emit through emitYAMLValueInline.
        if let entry = entries.first(where: { $0.key == key }), entry.parsedValue == value {
            return self
        }

        let emitted = emitYAMLValueInline(value)

        if let entry = entries.first(where: { $0.key == key }) {
            // Replace the value text in place.
            var newText = originalText
            newText.replaceSubrange(entry.valueRange, with: emitted)
            return reparsed(after: newText)
        }

        // Append before the closing delimiter — only meaningful if we have
        // a frontmatter region. If we don't, create one.
        if let bodyRange = frontmatterBodyRange {
            // Insert "<key>: <value>\n" at bodyRange.upperBound (which is the
            // position just before the closing `\n---`).
            var newText = originalText
            let appendage: String = {
                // If the body is empty, no leading newline; else newline-prefixed.
                if bodyRange.lowerBound == bodyRange.upperBound {
                    return "\(key): \(emitted)\n"
                }
                return "\n\(key): \(emitted)"
            }()
            newText.insert(contentsOf: appendage, at: bodyRange.upperBound)
            return reparsed(after: newText)
        }

        // No frontmatter region — synthesise one at the start.
        var newText = "---\n\(key): \(emitted)\n---\n"
        newText.append(originalText)
        return reparsed(after: newText)
    }

    /// Removes a frontmatter key. Spans the line including its full value
    /// range (which covers multi-line literal blocks) plus the trailing
    /// newline that separates entries.
    public func removingFrontmatter(_ key: String) -> BotFile {
        if case .frontmatterInvalidYAML = parseError { return self }

        guard let entry = entries.first(where: { $0.key == key }) else {
            return self
        }

        // The line starts at `<key>` and runs through entry.valueRange.upperBound.
        // We need to find the line start: walk back from valueRange.lowerBound
        // until we hit the start of text or a `\n`.
        let valueStart = entry.valueRange.lowerBound
        var lineStart = valueStart
        while lineStart > originalText.startIndex {
            let prev = originalText.index(before: lineStart)
            if originalText[prev] == "\n" { break }
            lineStart = prev
        }

        // Line end: include one trailing newline if present.
        let valueEnd = entry.valueRange.upperBound
        let lineEnd: String.Index = {
            if valueEnd < originalText.endIndex && originalText[valueEnd] == "\n" {
                return originalText.index(after: valueEnd)
            }
            return valueEnd
        }()

        var newText = originalText
        newText.removeSubrange(lineStart..<lineEnd)
        return reparsed(after: newText)
    }

    /// Re-parses `newText` to produce a fresh `BotFile`. Mutation primitives
    /// use this rather than hand-rolling consistent state.
    fileprivate func reparsed(after newText: String) -> BotFile {
        // The re-parse must succeed in the no-op-on-broken case, but if a
        // mutation produced syntactically invalid YAML somehow (it shouldn't),
        // we soft-fail per spec.
        if let reparsed = try? BotFile(fileURL: fileURL, text: newText) {
            return reparsed
        }
        return self
    }

    /// Emits a YAML value as a single-line scalar/flow expression suitable
    /// for splicing into frontmatter. Strings that contain reserved YAML
    /// characters are double-quoted.
    fileprivate func emitYAMLValueInline(_ value: YAMLValue) -> String {
        switch value {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .int(let i): return String(i)
        case .double(let d):
            if d.isNaN { return ".nan" }
            if d.isInfinite { return d > 0 ? ".inf" : "-.inf" }
            return String(d)
        case .string(let s): return needsQuoting(s) ? "\"\(escape(s))\"" : s
        case .array(let arr):
            return "[\(arr.map { emitYAMLValueInline($0) }.joined(separator: ", "))]"
        case .dictionary(let pairs):
            let inner =
                pairs
                .map { "\($0.0): \(emitYAMLValueInline($0.1))" }
                .joined(separator: ", ")
            return "{\(inner)}"
        }
    }

    private func needsQuoting(_ s: String) -> Bool {
        if s.isEmpty { return true }
        let reserved: Set<Character> = [
            ":", "#", "&", "*", "!", "|", ">", "'", "\"", "%", "@", "`", ",", "[", "]", "{", "}",
        ]
        if s.contains(where: { reserved.contains($0) || $0 == "\n" || $0 == "\t" }) { return true }
        if s.first == " " || s.last == " " { return true }
        // Leading YAML indicator characters (only dangerous in first position).
        if let first = s.first, "-?*&!|>%@`".contains(first) { return true }
        // YAML 1.2 boolean and null keywords (case-insensitive).
        if ["true", "false", "yes", "no", "null", "~"].contains(s.lowercased()) { return true }
        // Strings that would parse as numbers must be quoted to preserve string type.
        if Int(s) != nil || Double(s) != nil { return true }
        return false
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

extension BotFile {
    /// Replaces the prose region wholesale. Frontmatter is untouched.
    public func replacingProse(with newProse: String) -> BotFile {
        var newText = originalText
        newText.replaceSubrange(proseRange, with: newProse)
        return reparsed(after: newText)
    }

    /// Appends a markdown section at the end of prose:
    ///
    ///     <prose>
    ///     ## <heading>
    ///
    ///     <body>
    public func appendingProseSection(heading: String, body: String) -> BotFile {
        let existing = String(originalText[proseRange])
        let trimmed = existing.reversed().drop(while: { $0 == "\n" || $0 == "\r" })
        let stripped = String(trimmed.reversed())
        let separator = stripped.isEmpty ? "" : "\n\n"
        let newProse = stripped + separator + "## \(heading)\n\n\(body)\n"
        return replacingProse(with: newProse)
    }
}
