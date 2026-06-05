import SwiftUI
import b0tCore

/// The two small in/out token bars on the face crown — the glance view; the
/// Processor Controls tab is the drill-in. Spec §7.
public struct CrownTokenMetersView: View {
    let usage: GenerationUsage?
    public init(usage: GenerationUsage?) { self.usage = usage }
    public var body: some View {
        HStack(spacing: 4) {
            miniBar(value: usage?.tokensIn ?? 0, limit: usage?.limit ?? 0)
            miniBar(value: usage?.tokensOut ?? 0, limit: usage?.limit ?? 0)
        }.frame(width: 48, height: 6)
    }
    private func miniBar(value: Int, limit: Int) -> some View {
        let frac = limit > 0 ? min(1.0, Double(value) / Double(limit)) : 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(.secondary.opacity(0.25))
                Rectangle().fill(ProcessorPalette.yellow).frame(width: geo.size.width * frac)
            }
        }
    }
}
