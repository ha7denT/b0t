#if canImport(HealthKit)
    import Foundation
    import HealthKit

    /// The seam through which `b0tModules`'s health tools talk to HealthKit.
    ///
    /// `LiveHealthStore` (iOS only) wraps `HKHealthStore`. `FakeHealthStore`
    /// (test target, also iOS-only) carries scriptable in-memory state.
    ///
    /// `stepsToday()` is expressed as a high-level async method rather than
    /// threading `HKStatisticsQuery` through the protocol — keeps the fake
    /// trivial and lets the live impl encapsulate query construction.
    public protocol HealthStore: Sendable {
        func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
        func requestAuthorization(toShare: Set<HKSampleType>?, read: Set<HKObjectType>?) async throws
        func stepsToday() async throws -> Int
    }

    #if os(iOS)
        /// Production `HealthStore`. Wraps a single `HKHealthStore`.
        public struct LiveHealthStore: HealthStore {
            private let store: HKHealthStore

            public init(store: HKHealthStore = HKHealthStore()) {
                self.store = store
            }

            public func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
                store.authorizationStatus(for: type)
            }

            public func requestAuthorization(
                toShare: Set<HKSampleType>?,
                read: Set<HKObjectType>?
            ) async throws {
                try await store.requestAuthorization(toShare: toShare ?? [], read: read ?? [])
            }

            public func stepsToday() async throws -> Int {
                let stepType = HKQuantityType(.stepCount)
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: Date())
                let predicate = HKQuery.predicateForSamples(
                    withStart: startOfDay,
                    end: Date(),
                    options: .strictStartDate
                )
                return try await withCheckedThrowingContinuation { cont in
                    let query = HKStatisticsQuery(
                        quantityType: stepType,
                        quantitySamplePredicate: predicate,
                        options: .cumulativeSum
                    ) { _, statistics, error in
                        if let error {
                            cont.resume(throwing: error)
                            return
                        }
                        let count = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                        cont.resume(returning: Int(count))
                    }
                    self.store.execute(query)
                }
            }
        }
    #endif  // os(iOS)
#endif  // canImport(HealthKit)
