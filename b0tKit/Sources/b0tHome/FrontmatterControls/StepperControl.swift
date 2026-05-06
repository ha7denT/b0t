import SwiftUI

import b0tBrain
import b0tDesign

public struct StepperControl: View {
    let label: String
    @State private var current: Int
    let onCommit: @Sendable (YAMLValue) -> Void

    public init(label: String, value: Int, onCommit: @escaping @Sendable (YAMLValue) -> Void) {
        self.label = label
        self._current = State(initialValue: value)
        self.onCommit = onCommit
    }

    public var body: some View {
        Stepper(
            value: Binding(
                get: { current },
                set: { v in
                    current = v
                    commit(v)
                }
            )
        ) {
            Text("\(label): \(current)")
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
        }
    }

    func commit(_ i: Int) { onCommit(.int(i)) }
}
