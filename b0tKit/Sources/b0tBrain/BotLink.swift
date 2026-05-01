import Foundation

/// A markdown link found in prose: `[label](rawTarget)`.
public struct BotLink: Sendable, Equatable {
    public let label: String
    public let rawTarget: String
    public let resolution: BotLinkResolution
    public let sourceFileURL: URL

    public init(label: String, rawTarget: String, sourceFileURL: URL) {
        self.label = label
        self.rawTarget = rawTarget
        self.sourceFileURL = sourceFileURL
        self.resolution = Self.resolve(rawTarget: rawTarget, sourceFileURL: sourceFileURL)
    }

    /// Parses all inline `[label](target)` links from `prose`.
    public static func parse(prose: String, sourceFileURL: URL) -> [BotLink] {
        var links: [BotLink] = []
        let pattern = #"\[([^\]]*)\]\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return links
        }
        let nsProse = prose as NSString
        let range = NSRange(location: 0, length: nsProse.length)
        regex.enumerateMatches(in: prose, options: [], range: range) { match, _, _ in
            guard let m = match, m.numberOfRanges == 3 else { return }
            let label = nsProse.substring(with: m.range(at: 1))
            let target = nsProse.substring(with: m.range(at: 2))
            links.append(BotLink(label: label, rawTarget: target, sourceFileURL: sourceFileURL))
        }
        return links
    }

    private static func resolve(rawTarget: String, sourceFileURL: URL) -> BotLinkResolution {
        if rawTarget.hasPrefix("http://") || rawTarget.hasPrefix("https://"),
            let url = URL(string: rawTarget)
        {
            return .external(url)
        }
        // Treat as a relative path. Append `.md` if missing extension.
        let withExt = rawTarget.hasSuffix(".md") ? rawTarget : "\(rawTarget).md"
        let resolved =
            sourceFileURL
            .deletingLastPathComponent()
            .appendingPathComponent(withExt)
            .standardizedFileURL
        if FileManager.default.fileExists(atPath: resolved.path) {
            return .botFile(resolved)
        }
        return .botFileMissing(resolved)
    }
}

public enum BotLinkResolution: Sendable, Equatable {
    case botFile(URL)
    case botFileMissing(URL)
    case external(URL)
    case unresolvable(String)
}
