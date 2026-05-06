import SwiftUI

import b0tDesign
import b0tFace

/// The bottom-half LCD panel. Switches content based on `state.selectedOrgan`:
/// - nil → ChatView (default)
/// - any organ → OrganInspectionView (Slice 5+) or DirectoryNavigatorView (Slice 6+)
///
/// Phase 4 stubs the per-organ views with placeholders until Slices 5–6 fill them in.
public struct InspectionPanel: View {
    @Bindable var state: AnatomyState

    public init(state: AnatomyState) {
        self.state = state
    }

    public var body: some View {
        Group {
            if let organ = state.selectedOrgan {
                inspectionStub(for: organ)
            } else {
                ChatView(state: state)
            }
        }
        .background(LCDPalette.bgWarm)
        .overlay(alignment: .topLeading) {
            if state.selectedOrgan != nil {
                Button(action: { state.selectedOrgan = nil }) {
                    Text("‹ back")
                        .font(Typography.systemMono(size: 11))
                        .foregroundStyle(LCDPalette.textDim)
                        .padding(8)
                }
            }
        }
    }

    @ViewBuilder
    private func inspectionStub(for organ: OrganID) -> some View {
        VStack(spacing: 12) {
            Text(organ.rawValue.uppercased())
                .font(Typography.systemMono(size: 16))
                .foregroundStyle(LCDPalette.textAmber)
            Text("inspection view forthcoming (slice 5)")
                .font(Typography.systemMono(size: 11))
                .foregroundStyle(LCDPalette.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
