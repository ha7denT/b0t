import SwiftUI

import b0tDesign

/// Stub destination for the constant top-right gear (ADR-0019). The real
/// configuration surface (device prefs, TTS, trial/IAP, about) is deferred —
/// spec §6. This ships the affordance with voice-correct placeholder copy.
public struct ConfigurationPlaceholderView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("configuration")
                .font(Typography.systemMono(size: 16))
                .foregroundStyle(LCDPalette.textAmber)
            Text("not yet wired. device prefs, voice, and activation will live here.")
                .font(Typography.systemMono(size: 12))
                .foregroundStyle(LCDPalette.textDim)
            Text("all files local. no transmission.")
                .font(Typography.systemMono(size: 11))
                .foregroundStyle(LCDPalette.textDim.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(20)
        .background(LCDPalette.bgWarm)
    }
}

#Preview("configuration — stub") {
    ConfigurationPlaceholderView().background(Color.black)
}
