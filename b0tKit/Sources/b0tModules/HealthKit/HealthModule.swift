#if canImport(HealthKit) && os(iOS)
    import Foundation
    import HealthKit
    import FoundationModels
    import b0tBrain
    import b0tCore

    /// HealthKit bridge. Phase 3 supports `read_metrics: ["steps"]`; other
    /// metrics declared in frontmatter (sleep_hours, active_energy, etc.) are
    /// inert until later phases extend the surface.
    public struct HealthModule: Module {
        public static let id = "health"
        public let requiredPermissions: [PermissionKind]
        public let tools: [any Tool]

        public struct Parameters: Sendable {
            public let readMetrics: [String]

            public init(frontmatter: Frontmatter) throws {
                switch frontmatter["read_metrics"] {
                case .none, .null:
                    self.readMetrics = []
                case .array(let items):
                    self.readMetrics = try items.map { v in
                        guard case .string(let s) = v else {
                            throw ParametersError.invalid("read_metrics entries must be strings")
                        }
                        return s
                    }
                case .some(let other):
                    throw ParametersError.invalid("read_metrics must be array of strings, got \(other)")
                }
            }
        }

        public enum ParametersError: Error, Sendable {
            case invalid(String)
        }

        public init(parameters: Frontmatter) throws {
            try self.init(parameters: parameters, store: LiveHealthStore())
        }

        package init(parameters: Frontmatter, store: any HealthStore) throws {
            let params = try Parameters(frontmatter: parameters)
            let gate = PermissionGate(eventKit: LiveEventKitStore(), health: store)
            var tools: [any Tool] = []
            var ids: [HKQuantityTypeIdentifier] = []

            if params.readMetrics.contains("steps") {
                tools.append(HealthStepsTodayTool(store: store, gate: gate))
                ids.append(.stepCount)
            }
            // Future Phase 3.5+ adds sleep_hours, active_energy, etc.

            self.tools = tools
            self.requiredPermissions = ids.isEmpty ? [] : [.healthRead(ids)]
        }
    }
#endif
