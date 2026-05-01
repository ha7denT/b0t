import Foundation

// Typed views for canonical frontmatter keys. Each accessor is a pure
// projection over BotFile.frontmatter. Callers that don't care about
// schema can keep using the generic dict; these are ergonomic shorthands.

extension BotFile {
    /// `mutable` flag (identity files). Defaults to `true` if absent.
    public var mutable: Bool {
        if case .bool(let b) = frontmatter["mutable"] { return b }
        return true
    }

    /// `always_in_context` flag (identity, memory). Defaults to `false`.
    public var alwaysInContext: Bool {
        if case .bool(let b) = frontmatter["always_in_context"] { return b }
        return false
    }

    /// `load_on_demand` flag. Defaults to `false`.
    public var loadOnDemand: Bool {
        if case .bool(let b) = frontmatter["load_on_demand"] { return b }
        return false
    }

    /// `skill_id` (skill files). `nil` if absent.
    public var skillID: String? {
        if case .string(let s) = frontmatter["skill_id"] { return s }
        return nil
    }

    /// `enabled` flag (skill files). Defaults to `true`.
    public var enabled: Bool {
        if case .bool(let b) = frontmatter["enabled"] { return b }
        return true
    }
}
