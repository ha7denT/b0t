import SwiftUI

import b0tBrain
import b0tDesign
import b0tFace

/// The bottom-half LCD panel. Switches content based on `state.selectedOrgan`:
/// - nil → ChatView (default)
/// - .heart → OrganInspectionView over heartbeat/schedule.md (Slice 5)
/// - other organs → stub placeholder (Slice 6 fills in)
public struct InspectionPanel: View {
    @Bindable var state: AnatomyState

    public init(state: AnatomyState) {
        self.state = state
    }

    public var body: some View {
        Group {
            if let organ = state.selectedOrgan {
                inspectionContent(for: organ)
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
    private func inspectionContent(for organ: OrganID) -> some View {
        switch organ {
        case .heart:
            HeartInspectionContainer(state: state)
        default:
            VStack(spacing: 12) {
                Text(organ.rawValue.uppercased())
                    .font(Typography.systemMono(size: 16))
                    .foregroundStyle(LCDPalette.textAmber)
                Text("inspection forthcoming (slice 6)")
                    .font(Typography.systemMono(size: 11))
                    .foregroundStyle(LCDPalette.textDim)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Loads `heartbeat/schedule.md` asynchronously through `BotStore` and renders
/// `OrganInspectionView` once available. Reads each time the heart organ is selected.
private struct HeartInspectionContainer: View {
    @Bindable var state: AnatomyState
    @State private var file: BotFile?
    @State private var loadError: String?

    var body: some View {
        Group {
            if let file {
                OrganInspectionView(state: state, organ: .heart, file: file)
            } else if let loadError {
                Text("heartbeat/schedule.md unreadable. \(loadError)")
                    .font(Typography.systemMono(size: 12))
                    .foregroundStyle(LCDPalette.textDim)
                    .padding()
            } else {
                Text("loading…")
                    .font(Typography.systemMono(size: 12))
                    .foregroundStyle(LCDPalette.textDim)
                    .padding()
            }
        }
        .task(id: state.bot.heartbeat.scheduleURL) {
            do {
                file = try await state.store.read(state.bot.heartbeat.scheduleURL)
            } catch {
                loadError = String(describing: error)
            }
        }
    }
}
