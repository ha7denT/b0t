import SwiftUI

import b0tBrain
import b0tDesign

public struct EnumPickerControl: View {
    let label: String
    let options: [String]
    @State private var current: String
    let onCommit: @Sendable (YAMLValue) -> Void

    public init(
        label: String, options: [String], value: String,
        onCommit: @escaping @Sendable (YAMLValue) -> Void
    ) {
        self.label = label
        self.options = options
        self._current = State(initialValue: value)
        self.onCommit = onCommit
    }

    public var body: some View {
        HStack {
            Text(label)
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
            Spacer()
            Picker(
                "",
                selection: Binding(
                    get: { current },
                    set: { v in
                        current = v
                        onCommit(.string(v))
                    }
                )
            ) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }
}
