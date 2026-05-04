import Foundation

/// Marker protocol that lets `b0tCore`'s `ContextAssembler` detect which
/// `FoundationModels.Tool`s in `AssembledContext.tools` may request system
/// permissions at call time.
///
/// `Tool` is defined in `FoundationModels` and we cannot retroactively add
/// a requirement to it. Instead, permissioned tools also conform to
/// `PermissionAware`, and `ContextAssembler` checks via dynamic cast:
///
///     let needsAddendum = tools.contains { ($0 as? PermissionAware)?.requiresPermission == true }
///
/// Tools that don't conform are treated as `false` automatically.
public protocol PermissionAware {
    var requiresPermission: Bool { get }
}
