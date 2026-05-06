import SwiftUI

import b0tBrain
import b0tDesign

public struct BoolToggleControl: View {
    let label: String
    @State private var current: Bool
    let onCommit: @Sendable (YAMLValue) -> Void

    public init(label: String, value: Bool, onCommit: @escaping @Sendable (YAMLValue) -> Void) {
        self.label = label
        self._current = State(initialValue: value)
        self.onCommit = onCommit
    }

    public var body: some View {
        Toggle(
            isOn: Binding(
                get: { current },
                set: { newValue in
                    current = newValue
                    commit(newValue)
                }
            )
        ) {
            Text(label)
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
        }
        .tint(LCDPalette.textAmber)
    }

    func commit(_ b: Bool) { onCommit(.bool(b)) }
}
