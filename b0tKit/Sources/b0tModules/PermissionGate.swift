import EventKit
import Foundation

/// Single chokepoint for system-permission requests across all Modules.
///
/// Each `Module` instance constructs (or is injected) a `PermissionGate`
/// and shares it across its `tools`. A tool's `call(arguments:)`
/// invokes `await gate.ensure(.x)` before doing real work; on `false` it
/// returns `Output(permissionDenied: true, ...)` and skips the rest of
/// the tool's logic.
///
/// Slice 4 (T15): `.calendar` and `.reminders` dispatch through an
/// injected `EventKitStore`. `.healthRead` is a stub that returns `false`
/// until Slice 6 (T22) wires the health backend.
package actor PermissionGate {
    private let eventKit: any EventKitStore

    package init(eventKit: any EventKitStore = LiveEventKitStore()) {
        self.eventKit = eventKit
    }

    package func ensure(_ kind: PermissionKind) async -> Bool {
        switch kind {
        case .calendar:
            return await ensureEventKit(.event)
        case .reminders:
            return await ensureEventKit(.reminder)
        #if canImport(HealthKit)
            case .healthRead:
                // T22 wires the health backend.
                return false
        #endif
        }
    }

    private func ensureEventKit(_ entityType: EKEntityType) async -> Bool {
        let status = eventKit.authorizationStatus(for: entityType)
        switch status {
        case .fullAccess, .authorized:
            return true
        case .notDetermined:
            return (try? await eventKit.requestAccess(to: entityType)) ?? false
        case .denied, .restricted, .writeOnly:
            return false
        @unknown default:
            return false
        }
    }
}
