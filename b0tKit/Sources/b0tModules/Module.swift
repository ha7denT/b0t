import Foundation
import FoundationModels
import b0tBrain

#if canImport(HealthKit)
    import HealthKit
#endif

/// A capability bridge for the b0t — a Swift type that owns a slice of system
/// access (calendar, reminders, health, etc.) and exposes one or more
/// `FoundationModels.Tool`s the model can call during a turn or tick.
///
/// One markdown file in `<bot>/modules/` declares one Module, identified by
/// its `module_id` frontmatter key. `ModuleRegistry.loadModules(for:)` reads
/// the markdown, looks up the matching Swift type via the registry's
/// dispatch table, decodes the file's frontmatter into the Module's typed
/// `Parameters`, and returns the instantiated Module.
///
/// `Module` returns `[any Tool]` directly — there is no `ToolHandle`
/// indirection. `FoundationModels.Tool` already encodes the MCP shape via
/// `@Generable` (name, description, JSON-schema input, JSON-encodable output);
/// a wrapper would just re-serialise. See spec §3 Q4 and ADR-0008.
///
/// Modules are `Sendable` because their tools cross actor boundaries inside
/// `LanguageModelSession`.
public protocol Module: Sendable {
    /// Stable identifier matching the `module_id` frontmatter key.
    static var id: String { get }

    /// System permissions this Module's tools may request at call time.
    /// Empty array → permissionless (e.g. `TimeAwarenessModule`).
    var requiredPermissions: [PermissionKind] { get }

    /// `FoundationModels.Tool` instances this Module exposes to the session.
    /// Several related tools per Module is fine (e.g. RemindersModule has
    /// both `reminders.create` and `reminders.list`).
    var tools: [any Tool] { get }

    /// Decode typed parameters from the Module's `.md` frontmatter.
    /// Throws if frontmatter is missing required keys, has wrong types, or
    /// otherwise fails the Module's `Parameters` schema.
    init(parameters: Frontmatter) throws
}

/// System permissions a `Module`'s tools may request.
///
/// `.healthRead` carries the specific HealthKit quantity types because
/// HealthKit's `requestAuthorization(toShare:read:)` is per-type. Calendar
/// and Reminders are single-permission so they carry no payload.
public enum PermissionKind: Sendable, Equatable {
    case calendar
    case reminders
    #if canImport(HealthKit)
        case healthRead([HKQuantityTypeIdentifier])
    #endif

    public static func == (lhs: PermissionKind, rhs: PermissionKind) -> Bool {
        switch (lhs, rhs) {
        case (.calendar, .calendar): return true
        case (.reminders, .reminders): return true
        #if canImport(HealthKit)
            case (.healthRead(let a), .healthRead(let b)):
                return a.map(\.rawValue).sorted() == b.map(\.rawValue).sorted()
        #endif
        default: return false
        }
    }
}
