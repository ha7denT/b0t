import SwiftUI

import b0tBrain
import b0tDesign

public struct TextFieldControl: View {
    let label: String
    @State private var current: String
    let onCommit: @Sendable (YAMLValue) -> Void

    public init(label: String, value: String, onCommit: @escaping @Sendable (YAMLValue) -> Void) {
        self.label = label
        self._current = State(initialValue: value)
        self.onCommit = onCommit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Typography.systemMono(size: 11))
                .foregroundStyle(LCDPalette.textDim)
            TextField(
                "",
                text: Binding(
                    get: { current },
                    set: { v in
                        current = v
                        commit(v)
                    }
                )
            )
            .font(Typography.systemMono(size: 13))
            .foregroundStyle(LCDPalette.textAmber)
            .textFieldStyle(.plain)
        }
    }

    func commit(_ s: String) { onCommit(.string(s)) }
}
