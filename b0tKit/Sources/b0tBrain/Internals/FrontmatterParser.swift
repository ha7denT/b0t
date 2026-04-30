import Foundation
import Yams

internal enum FrontmatterParser {
    enum ParseError: Error, Equatable {
        case invalidYAML(message: String)
    }

    struct Entry {
        let key: String
        let valueRange: Range<String.Index>  // range into the original frontmatter substring
        let parsedValue: YAMLValue
    }

    struct Result {
        let frontmatter: Frontmatter
        let entries: [Entry]
    }

    /// Parses `text` (the frontmatter body, without delimiters) into a typed
    /// projection plus entries that retain byte ranges into `text`.
    ///
    /// The byte ranges are computed by scanning for top-level `key:` lines.
    /// Multi-line literal blocks (`key: |`, `key: >`) and nested YAML are
    /// supported by Yams parsing; for byte-range purposes we treat the entire
    /// remainder of an entry (until the next top-level key or end of text) as
    /// the value range.
    static func parse(_ text: String) throws -> Result {
        guard !text.isEmpty else {
            return Result(frontmatter: Frontmatter(), entries: [])
        }

        // Yams gives us a typed parse. Use Node.mapping for ordered key access.
        let node: Node
        do {
            guard let parsed = try Yams.compose(yaml: text) else {
                return Result(frontmatter: Frontmatter(), entries: [])
            }
            node = parsed
        } catch {
            throw ParseError.invalidYAML(message: String(describing: error))
        }

        guard case .mapping(let mapping) = node else {
            // A scalar or list at the root isn't a frontmatter shape we accept.
            throw ParseError.invalidYAML(message: "frontmatter root must be a mapping")
        }

        var orderedPairs: [(String, YAMLValue)] = []
        var keyOrder: [String] = []
        for pair in mapping {
            guard case .scalar(let keyScalar) = pair.key else {
                throw ParseError.invalidYAML(message: "non-scalar frontmatter key")
            }
            let key = keyScalar.string
            keyOrder.append(key)
            orderedPairs.append((key, try yamlValue(from: pair.value)))
        }

        let entries = locateEntries(in: text, keysInOrder: keyOrder)
        let zipped = zip(entries, orderedPairs).map { entry, pair in
            Entry(key: entry.key, valueRange: entry.valueRange, parsedValue: pair.1)
        }
        return Result(
            frontmatter: Frontmatter(orderedPairs: orderedPairs),
            entries: zipped
        )
    }

    private static func yamlValue(from node: Node) throws -> YAMLValue {
        switch node {
        case .scalar(let scalar):
            return scalarYAMLValue(scalar)
        case .sequence(let seq):
            return .array(try seq.map { try yamlValue(from: $0) })
        case .mapping(let map):
            var pairs: [(String, YAMLValue)] = []
            for kv in map {
                guard case .scalar(let s) = kv.key else {
                    throw ParseError.invalidYAML(message: "nested non-scalar key")
                }
                pairs.append((s.string, try yamlValue(from: kv.value)))
            }
            return .dictionary(pairs)
        case .alias:
            // Anchors/aliases are not part of the supported frontmatter shape.
            throw ParseError.invalidYAML(message: "YAML aliases are not supported in frontmatter")
        }
    }

    private static func scalarYAMLValue(_ scalar: Node.Scalar) -> YAMLValue {
        let raw = scalar.string
        if scalar.style == .doubleQuoted || scalar.style == .singleQuoted {
            return .string(raw)
        }
        switch raw.lowercased() {
        case "true", "yes": return .bool(true)
        case "false", "no": return .bool(false)
        case "null", "~", "": return .null
        default: break
        }
        if let i = Int(raw) { return .int(i) }
        if let d = Double(raw) { return .double(d) }
        return .string(raw)
    }

    /// Scans `text` for top-level `key:` markers and returns each key's
    /// `valueRange` — the bytes from the character after `key:` (skipping the
    /// single space if present) to the end of that logical entry.
    private static func locateEntries(
        in text: String,
        keysInOrder: [String]
    ) -> [(key: String, valueRange: Range<String.Index>)] {
        var found: [(key: String, valueRange: Range<String.Index>)] = []
        var lineStart = text.startIndex
        var keyStartsByOrder: [(key: String, lineRange: Range<String.Index>, valueStart: String.Index)] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            let lineEnd = text.index(lineStart, offsetBy: line.count)
            // Skip indented lines (continuation of a previous value).
            if let firstChar = line.first, firstChar != " ", firstChar != "\t",
                !line.hasPrefix("#")
            {
                if let colonIdx = line.firstIndex(of: ":") {
                    let keyText = String(line[line.startIndex..<colonIdx])
                    if keysInOrder.contains(keyText) {
                        // valueStart: char after `:`. Skip a single leading space if present.
                        var valueStart = text.index(lineStart, offsetBy: keyText.count + 1)
                        if valueStart < text.endIndex, text[valueStart] == " " {
                            valueStart = text.index(after: valueStart)
                        }
                        keyStartsByOrder.append(
                            (
                                key: keyText,
                                lineRange: lineStart..<lineEnd,
                                valueStart: valueStart
                            ))
                    }
                }
            }
            lineStart = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
        }

        // valueRange runs from valueStart to (next entry's lineRange.lowerBound, or end of text).
        for (i, item) in keyStartsByOrder.enumerated() {
            let endIdx: String.Index
            if i + 1 < keyStartsByOrder.count {
                endIdx = keyStartsByOrder[i + 1].lineRange.lowerBound
                // Trim the trailing newline that separates entries, so the
                // value range doesn't include the `\n` between this entry and
                // the next one.
                let trimmed = trimTrailingNewline(in: text, before: endIdx)
                found.append((item.key, item.valueStart..<trimmed))
            } else {
                let trimmed = trimTrailingNewline(in: text, before: text.endIndex)
                found.append((item.key, item.valueStart..<trimmed))
            }
        }
        return found
    }

    private static func trimTrailingNewline(
        in text: String,
        before idx: String.Index
    ) -> String.Index {
        guard idx > text.startIndex else { return idx }
        let prev = text.index(before: idx)
        return text[prev] == "\n" ? prev : idx
    }
}
