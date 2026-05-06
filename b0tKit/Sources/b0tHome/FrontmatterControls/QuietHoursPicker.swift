import SwiftUI

import b0tBrain
import b0tDesign

/// Specialised range picker for `quiet_hours` frontmatter.
/// Supports overnight ranges (e.g. 22:00 → 06:30) as is — passes the values through
/// to YAML as a 2-element array of HH:MM strings.
public struct QuietHoursPicker: View {
    @State private var start: String
    @State private var end: String
    let onCommit: @Sendable (YAMLValue) -> Void

    public init(start: String, end: String, onCommit: @escaping @Sendable (YAMLValue) -> Void) {
        self._start = State(initialValue: start)
        self._end = State(initialValue: end)
        self.onCommit = onCommit
    }

    public var isOvernight: Bool {
        // crude lexicographic compare on HH:MM works because of zero-padding
        start > end
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("quiet hours")
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
            HStack {
                clockField(label: "start", value: $start)
                Text("→").foregroundStyle(LCDPalette.textDim)
                clockField(label: "end", value: $end)
            }
            if isOvernight {
                Text("overnight (wraps past midnight)")
                    .font(Typography.systemMono(size: 10))
                    .foregroundStyle(LCDPalette.textDim)
            }
        }
    }

    private func clockField(label: String, value: Binding<String>) -> some View {
        TextField(
            label,
            text: Binding(
                get: { value.wrappedValue },
                set: { v in
                    value.wrappedValue = v
                    commit(start: start, end: end)
                }
            )
        )
        .font(Typography.systemMono(size: 13))
        .foregroundStyle(LCDPalette.textAmber)
        .frame(width: 64)
        .textFieldStyle(.plain)
    }

    func commit(start: String, end: String) {
        onCommit(.array([.string(start), .string(end)]))
    }
}
