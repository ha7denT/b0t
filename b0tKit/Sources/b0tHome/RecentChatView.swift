import SwiftUI

import b0tBrain
import b0tDesign

/// The inspector's zero-state in workbench mode (ADR-0019): a compact view of
/// the latest chat turns, tappable to return to full chat mode. Shown when no
/// organ is selected.
public struct RecentChatView: View {
    @Bindable var state: AnatomyState

    public init(state: AnatomyState) {
        self.state = state
    }

    /// The last two non-status turns from the shared transcript.
    var latestTurns: [ChatTurn] {
        state.transcript.filter { $0.role != .status }.suffix(2).map { $0 }
    }

    /// Switch the home screen back to chat mode.
    func returnToChat() {
        state.mode = .chat
    }

    public var body: some View {
        Button(action: returnToChat) {
            VStack(alignment: .leading, spacing: 8) {
                Text("▸ no organ selected — latest chat")
                    .font(Typography.systemMono(size: 10))
                    .foregroundStyle(LCDPalette.textDim)
                ForEach(latestTurns) { turn in
                    Text(turn.text)
                        .font(Typography.chatBody(size: 13))
                        .foregroundStyle(LCDPalette.textAmber)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("tap to return to chat ▸")
                    .font(Typography.systemMono(size: 10))
                    .foregroundStyle(LCDPalette.textDim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .buttonStyle(.plain)
        .background(LCDPalette.bgWarm)
    }
}

#Preview("inspector — recent chat zero-state") {
    let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/preview"))
    let store = BotStore()
    let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
    return RecentChatView(state: state).frame(height: 200).background(Color.black)
}
