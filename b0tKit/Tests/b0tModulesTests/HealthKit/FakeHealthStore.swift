#if canImport(HealthKit) && os(iOS)
    import Foundation
    import HealthKit

    @testable import b0tModules

    /// Scriptable in-memory `HealthStore` for unit tests. Tests set
    /// `scriptedGrant = true/false` to control `requestAuthorization`'s
    /// resolution; `scriptedStepsToday` controls the `stepsToday()` return.
    final class FakeHealthStore: HealthStore, @unchecked Sendable {
        var scriptedGrant: Bool = false
        var scriptedStepsToday: Int = 0
        private var status: [HKObjectType: HKAuthorizationStatus] = [:]

        func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
            status[type] ?? .notDetermined
        }

        func requestAuthorization(toShare: Set<HKSampleType>?, read: Set<HKObjectType>?) async throws {
            for type in read ?? [] {
                status[type] = scriptedGrant ? .sharingAuthorized : .sharingDenied
            }
        }

        func stepsToday() async throws -> Int {
            scriptedStepsToday
        }
    }
#endif
