import b0tBrain

public enum FrontmatterTypeRegistry {
    public static func kind(for value: YAMLValue) -> FrontmatterControlKind? {
        switch value {
        case .bool: return .toggle
        case .int: return .stepper
        case .string: return .textField
        // .double / .array / .dictionary / .null → fall through; no generic control yet.
        default: return nil
        }
    }
}
