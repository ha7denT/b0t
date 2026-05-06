import SwiftUI

import b0tBrain
import b0tDesign

public struct ClockTimePickerControl: View {
    let label: String
    @State private var current: Date
    let onCommit: @Sendable (YAMLValue) -> Void

    public init(
        label: String, hours: Int, minutes: Int,
        onCommit: @escaping @Sendable (YAMLValue) -> Void
    ) {
        self.label = label
        var comps = DateComponents()
        comps.hour = hours
        comps.minute = minutes
        let d = Calendar.current.date(from: comps) ?? Date()
        self._current = State(initialValue: d)
        self.onCommit = onCommit
    }

    public var body: some View {
        HStack {
            Text(label)
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
            Spacer()
            DatePicker(
                "",
                selection: Binding(
                    get: { current },
                    set: { d in
                        current = d
                        commit(d)
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
    }

    func commit(_ d: Date) {
        let h = Calendar.current.component(.hour, from: d)
        let m = Calendar.current.component(.minute, from: d)
        onCommit(.string(String(format: "%02d:%02d", h, m)))
    }
}
