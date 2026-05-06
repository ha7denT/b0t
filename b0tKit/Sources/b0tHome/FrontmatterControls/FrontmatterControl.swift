import SwiftUI

import b0tBrain

/// What kind of control should render for this frontmatter field.
public enum FrontmatterControlKind: Sendable {
    case bpmSlider
    case quietHoursPicker
    case enabledToggle
    case toggle  // generic Bool fallback
    case stepper  // generic Int fallback
    case clockTimePicker  // generic ClockTime fallback
    case clockRangePicker  // generic ClockRange fallback
    case enumPicker  // String matching a known enum
    case textField  // String fallback
}

/// A renderable control for a single frontmatter field.
public struct FrontmatterControlSpec: Sendable {
    public let key: String
    public let kind: FrontmatterControlKind
    public let value: YAMLValue
    public let onUpdate: @Sendable (YAMLValue) -> Void
}

/// The dispatcher: semantic registry first, then type fallback.
public enum FrontmatterControlDispatcher {
    public static func control(
        forKey key: String,
        value: YAMLValue,
        onUpdate: @escaping @Sendable (YAMLValue) -> Void
    ) -> FrontmatterControlSpec? {
        if let semantic = FrontmatterSemanticRegistry.kind(forKey: key) {
            return FrontmatterControlSpec(
                key: key, kind: semantic, value: value, onUpdate: onUpdate)
        }
        if let typed = FrontmatterTypeRegistry.kind(for: value) {
            return FrontmatterControlSpec(
                key: key, kind: typed, value: value, onUpdate: onUpdate)
        }
        return nil
    }
}
