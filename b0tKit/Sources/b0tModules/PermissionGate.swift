import Foundation

/// Single chokepoint for system-permission requests across all Modules.
///
/// Each `Module` instance constructs (or is injected) a `PermissionGate`
/// and shares it across its `tools`. A tool's `call(arguments:)`
/// invokes `await gate.ensure(.x)` before doing real work; on `false` it
/// returns `Output(permissionDenied: true, …)` and leaves the rest of
/// the tool's logic skipped.
///
/// Construction takes injected backends (slice 4 wires `EventKitStore` for
/// `.calendar` and `.reminders`; slice 6 wires `HealthStore` for
/// `.healthRead`). Slice 1 ships the actor with empty initialisation;
/// every `ensure(_:)` call traps at runtime. That's intentional: no
/// production code path can reach the gate yet.
package actor PermissionGate {
    package init() {}

    package func ensure(_ kind: PermissionKind) async -> Bool {
        // Replaced slice-by-slice as backends land.
        // Slice 4: .calendar, .reminders cases via EventKitStore
        // Slice 6: .healthRead via HealthStore
        switch kind {
        case .calendar, .reminders:
            fatalError("PermissionGate.ensure not yet implemented for \(kind) — slice 4")
        #if canImport(HealthKit)
            case .healthRead:
                fatalError("PermissionGate.ensure not yet implemented for \(kind) — slice 6")
        #endif
        }
    }
}
