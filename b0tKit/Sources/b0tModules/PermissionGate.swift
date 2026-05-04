import EventKit
import Foundation

#if canImport(HealthKit) && os(iOS)
    import HealthKit
#endif

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

    #if canImport(HealthKit) && os(iOS)
        private let health: any HealthStore
    #endif

    #if canImport(HealthKit) && os(iOS)
        package init(
            eventKit: any EventKitStore = LiveEventKitStore(),
            health: any HealthStore = LiveHealthStore()
        ) {
            self.eventKit = eventKit
            self.health = health
        }
    #else
        package init(eventKit: any EventKitStore = LiveEventKitStore()) {
            self.eventKit = eventKit
        }
    #endif

    package func ensure(_ kind: PermissionKind) async -> Bool {
        switch kind {
        case .calendar:
            return await ensureEventKit(.event)
        case .reminders:
            return await ensureEventKit(.reminder)
        #if canImport(HealthKit)
            case .healthRead(let identifiers):
                #if os(iOS)
                    return await ensureHealthRead(identifiers)
                #else
                    return false
                #endif
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

    #if canImport(HealthKit) && os(iOS)
        private func ensureHealthRead(_ identifiers: [HKQuantityTypeIdentifier]) async -> Bool {
            // HealthKit's read-permission state is not observable post-prompt.
            // We cannot reliably distinguish "denied" from "never asked" via
            // authorizationStatus(for:) for read intents — Apple deliberately
            // hides this. So we just request, trusting the system to dedupe
            // re-prompts. Returning true means "we tried"; the actual data
            // query in HealthStepsTodayTool handles "no data" gracefully.
            let types: Set<HKObjectType> = Set(identifiers.map { HKQuantityType($0) })
            do {
                try await health.requestAuthorization(toShare: nil, read: types)
                return true
            } catch {
                return false
            }
        }
    #endif
}
