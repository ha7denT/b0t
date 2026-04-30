import Foundation

/// A YAML scalar/collection value, preserving on-disk key order for dictionaries.
///
/// `YAMLValue` is the public projection of frontmatter contents. Internally the
/// frontmatter parser also retains the original byte text per key for lossless
/// round-tripping; that detail is intentionally not exposed here.
public enum YAMLValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([YAMLValue])
    case dictionary([(String, YAMLValue)])
    case null

    public static func == (lhs: YAMLValue, rhs: YAMLValue) -> Bool {
        switch (lhs, rhs) {
        case (.string(let a), .string(let b)): return a == b
        case (.int(let a), .int(let b)): return a == b
        case (.double(let a), .double(let b)): return a == b
        case (.bool(let a), .bool(let b)): return a == b
        case (.array(let a), .array(let b)): return a == b
        case (.dictionary(let a), .dictionary(let b)):
            guard a.count == b.count else { return false }
            return zip(a, b).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        case (.null, .null): return true
        default: return false
        }
    }
}

/// An ordered, immutable view of frontmatter keys and values.
///
/// `Frontmatter` is the public projection. The parser additionally retains
/// original byte ranges per key (in an internal Entry list on `BotFile`) used
/// for surgical-patch round-tripping.
public struct Frontmatter: Sendable, Equatable {
    public let keys: [String]
    private let storage: [String: YAMLValue]

    public init() {
        self.keys = []
        self.storage = [:]
    }

    internal init(orderedPairs: [(String, YAMLValue)]) {
        self.keys = orderedPairs.map(\.0)
        self.storage = Dictionary(uniqueKeysWithValues: orderedPairs)
    }

    public subscript(key: String) -> YAMLValue? { storage[key] }

    public func contains(_ key: String) -> Bool { storage[key] != nil }

    public static func == (lhs: Frontmatter, rhs: Frontmatter) -> Bool {
        guard lhs.keys == rhs.keys else { return false }
        return lhs.keys.allSatisfy { lhs.storage[$0] == rhs.storage[$0] }
    }
}
