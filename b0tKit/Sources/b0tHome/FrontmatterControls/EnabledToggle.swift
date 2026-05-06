import SwiftUI

import b0tBrain
import b0tDesign

/// Specialised toggle for `enabled:` frontmatter — labels with the module name.
public struct EnabledToggle: View {
    let moduleName: String
    @State private var current: Bool
    let onCommit: @Sendable (YAMLValue) -> Void

    public init(
        moduleName: String, value: Bool, onCommit: @escaping @Sendable (YAMLValue) -> Void
    ) {
        self.moduleName = moduleName
        self._current = State(initialValue: value)
        self.onCommit = onCommit
    }

    public var body: some View {
        Toggle(
            isOn: Binding(
                get: { current },
                set: { v in
                    current = v
                    commit(v)
                }
            )
        ) {
            Text("\(moduleName) enabled")
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
        }
        .tint(LCDPalette.textAmber)
    }

    func commit(_ b: Bool) { onCommit(.bool(b)) }
}
