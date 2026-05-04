import Foundation
import FoundationModels
import b0tBrain
import b0tCore

public struct CalendarModule: Module {
    public static let id = "calendar"
    public let requiredPermissions: [PermissionKind] = [.calendar]
    public let tools: [any Tool]

    public struct Parameters: Sendable {
        public let lookaheadHours: Int
        public let verbosity: String
        public let quietForRoutine: Bool

        public init(frontmatter: Frontmatter) throws {
            switch frontmatter["lookahead_hours"] {
            case .none, .null:
                self.lookaheadHours = 24
            case .int(let n):
                guard n > 0 else {
                    throw ParametersError.invalid("lookahead_hours must be positive, got \(n)")
                }
                self.lookaheadHours = n
            case .some(let other):
                throw ParametersError.invalid("lookahead_hours must be Int, got \(other)")
            }

            switch frontmatter["verbosity"] {
            case .none, .null:
                self.verbosity = "medium"
            case .string(let s):
                self.verbosity = s
            case .some(let other):
                throw ParametersError.invalid("verbosity must be String, got \(other)")
            }

            switch frontmatter["quiet_for_routine"] {
            case .none, .null:
                self.quietForRoutine = true
            case .bool(let b):
                self.quietForRoutine = b
            case .some(let other):
                throw ParametersError.invalid("quiet_for_routine must be Bool, got \(other)")
            }
        }
    }

    public enum ParametersError: Error, Sendable {
        case invalid(String)
    }

    public init(parameters: Frontmatter) throws {
        try self.init(parameters: parameters, store: LiveEventKitStore())
    }

    package init(parameters: Frontmatter, store: any EventKitStore) throws {
        let params = try Parameters(frontmatter: parameters)
        let gate = PermissionGate(eventKit: store)
        self.tools = [
            CalendarUpcomingEventsTool(
                store: store,
                gate: gate,
                clock: SystemClock(),
                defaultLookaheadHours: params.lookaheadHours
            )
        ]
    }
}
