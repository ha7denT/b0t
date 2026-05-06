import SwiftUI

import b0tBrain
import b0tDesign

/// Specialised BPM control per spec §4.6 semantic registry.
/// Range 1...12 (one beat per minute up to 12 — tunable upstream if needed).
public struct BPMSlider: View {
    @State private var current: Double
    let onCommit: @Sendable (YAMLValue) -> Void

    public init(value: Int, onCommit: @escaping @Sendable (YAMLValue) -> Void) {
        self._current = State(initialValue: Double(value))
        self.onCommit = onCommit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("♡ \(Int(current.rounded())) bpm")
                    .font(Typography.systemMono(size: 13))
                    .foregroundStyle(LCDPalette.textAmber)
                Spacer()
            }
            Slider(
                value: Binding(
                    get: { current },
                    set: { newValue in
                        current = newValue
                        commit(Int(newValue.rounded()))
                    }
                ),
                in: 1.0...12.0,
                step: 1.0
            )
            .tint(LCDPalette.textAmber)
        }
        .padding(.vertical, 6)
    }

    func commit(_ bpm: Int) {
        let clamped = min(max(bpm, 1), 12)
        onCommit(.int(clamped))
    }
}
