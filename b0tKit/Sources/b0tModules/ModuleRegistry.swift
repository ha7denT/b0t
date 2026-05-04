import Foundation
import OSLog
import b0tBrain

/// Loads `Module` instances from a b0t's `modules/` directory.
///
/// Each `.md` file's frontmatter is read; the `module_id` is looked up in
/// the registry's static `factories` dispatch table. Known ids → factory
/// invoked with the file's frontmatter, instantiating the Module. Unknown
/// ids and `enabled: false` files are logged-and-skipped (lenient policy
/// per spec Q7). Missing `module_id` and per-Module parameter-decode
/// failures throw `ModuleLoadError`.
///
/// Adding a Module post-Phase-3 means: define a struct conforming to
/// `Module`, add one entry to `factories`. That's the v1 form of ADR-0008's
/// marketplace-compatibility seam.
public enum ModuleRegistry {
    private static let logger = Logger(
        subsystem: "com.toppeross.b0t.b0tModules",
        category: "ModuleRegistry"
    )

    /// Module-id → factory closure. Slice 1 starts empty. Each subsequent
    /// slice adds entries: slice 2 adds TimeAwarenessModule, slice 4 adds
    /// CalendarModule, slice 5 adds RemindersModule, slice 6 adds HealthModule
    /// (conditionally on iOS).
    private static var factories: [String: @Sendable (Frontmatter) throws -> any Module] {
        var table: [String: @Sendable (Frontmatter) throws -> any Module] = [:]
        table[TimeAwarenessModule.id] = { try TimeAwarenessModule(parameters: $0) }
        table[CalendarModule.id] = { try CalendarModule(parameters: $0) }
        // Slice 5 adds RemindersModule
        // Slice 6 adds HealthModule (#if canImport(HealthKit) && os(iOS))
        return table
    }

    /// Read `<bot>/modules/*.md`, resolve known modules to factories,
    /// skip unknown/disabled, throw on malformed.
    ///
    /// Returns Modules in alphabetical filename order (the iteration order
    /// of `ModulesSection.all`).
    public static func loadModules(for bot: Bot) async throws -> [any Module] {
        let files = try await bot.modules.all
        var modules: [any Module] = []
        for file in files {
            // enabled: false → silent skip
            if !file.enabled {
                continue
            }

            // module_id missing → throw (user-fixable error)
            guard let id = file.moduleID else {
                throw ModuleLoadError.missingModuleID(file: file.fileURL)
            }

            // unknown id → debug log, skip
            guard let factory = factories[id] else {
                logger.debug(
                    "unknown module_id '\(id, privacy: .public)' in modules/\(file.fileURL.lastPathComponent, privacy: .public) — skipped"
                )
                continue
            }

            // known id → instantiate; per-Module parameter-decode errors
            // get wrapped so the caller knows which Module rejected.
            do {
                modules.append(try factory(file.frontmatter))
            } catch {
                throw ModuleLoadError.invalidParameters(moduleID: id, underlying: error)
            }
        }
        return modules
    }
}
