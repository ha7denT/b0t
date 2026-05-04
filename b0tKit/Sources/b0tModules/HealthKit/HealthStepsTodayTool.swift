#if canImport(HealthKit) && os(iOS)
    import Foundation
    import HealthKit
    import FoundationModels
    import b0tBrain
    import b0tCore

    /// Returns the user's step count from local-midnight to now, via HealthKit.
    ///
    /// HealthKit deliberately hides denied-read permission state — the
    /// underlying `authorizationStatus(for:)` returns `.notDetermined` whether
    /// the user hasn't been asked or has explicitly denied. This tool calls
    /// the gate (which requests authorization), then queries unconditionally.
    /// A zero step count is reported as `permissionDenied: false` because we
    /// genuinely can't tell "denied" from "actually zero" — the b0t handles
    /// the ambiguity in voice ("you've been still today"). See spec §3
    /// sub-decisions and ADR §6.4.
    public struct HealthStepsTodayTool: Tool, PermissionAware, Sendable {
        public let name = "health.steps_today"
        public let description =
            "Returns the user's step count from local-midnight to now, via HealthKit."
        public var requiresPermission: Bool { true }

        @Generable
        public struct Arguments: Sendable {
            public init() {}
        }

        @Generable
        public struct Output: Sendable {
            public let stepCount: Int
            public let permissionDenied: Bool
            public init(stepCount: Int, permissionDenied: Bool) {
                self.stepCount = stepCount
                self.permissionDenied = permissionDenied
            }
        }

        private let store: any HealthStore
        private let gate: PermissionGate

        package init(store: any HealthStore, gate: PermissionGate) {
            self.store = store
            self.gate = gate
        }

        public func call(arguments: Arguments) async throws -> Output {
            guard await gate.ensure(.healthRead([.stepCount])) else {
                return Output(stepCount: 0, permissionDenied: true)
            }
            do {
                let count = try await store.stepsToday()
                return Output(stepCount: count, permissionDenied: false)
            } catch {
                // Treat query failure as zero steps. Don't infer denial — the
                // HealthKit denial-hiding constraint means we cannot reliably
                // distinguish "denied" from "no data".
                return Output(stepCount: 0, permissionDenied: false)
            }
        }
    }

    extension HealthStepsTodayTool {
        public static func summarize(_ a: Arguments) -> String { "(no args)" }
        public static func summarize(_ o: Output) -> String {
            o.permissionDenied
                ? "permissionDenied: true"
                : "stepCount: \(o.stepCount)"
        }
    }
#endif
