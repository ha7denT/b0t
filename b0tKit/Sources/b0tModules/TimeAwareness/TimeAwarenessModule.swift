import Foundation
import FoundationModels
import b0tBrain
import b0tCore

/// The simplest possible `Module`: wraps `TimeAwarenessTool`, takes no
/// parameters from frontmatter, requires no permissions. Exists so the
/// model has a no-cost way to anchor its replies in current time, and so
/// `b0tModules` has a permissionless reference Module to test the registry
/// pipeline against before EventKit/HealthKit land.
public struct TimeAwarenessModule: Module {
    public static let id = "time-awareness"
    public let requiredPermissions: [PermissionKind] = []
    public let tools: [any Tool]

    public init(parameters: Frontmatter) throws {
        try self.init(parameters: parameters, clock: SystemClock())
    }

    public init(parameters: Frontmatter, clock: any Clock) throws {
        // No parameters to decode. Frontmatter is accepted but unused.
        _ = parameters
        self.tools = [TimeAwarenessTool(clock: clock)]
    }
}
