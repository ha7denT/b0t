import Foundation
import FoundationModels
import b0tBrain
import b0tCore

public struct RemindersModule: Module {
    public static let id = "reminders"
    public let requiredPermissions: [PermissionKind] = [.reminders]
    public let tools: [any Tool]

    public struct Parameters: Sendable {
        public let defaultList: String

        public init(frontmatter: Frontmatter) throws {
            switch frontmatter["default_list"] {
            case .none, .null:
                self.defaultList = "b0t"
            case .string(let s):
                self.defaultList = s
            case .some(let other):
                throw ParametersError.invalid("default_list must be String, got \(other)")
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
            RemindersCreateTool(store: store, gate: gate, defaultListName: params.defaultList),
            RemindersListTool(store: store, gate: gate),
        ]
    }
}
