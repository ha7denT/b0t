import SwiftUI

import b0tBrain
import b0tDesign

/// Default LCD content — chat scrollback and composer.
///
/// Phase 4 wires this to the existing `ConversationManager` from b0tCore. The visual
/// chrome is the LCD treatment (warm-amber backlit, Verdana for chat content,
/// IoskeleyMono for system labels).
public struct ChatView: View {
    @Bindable var state: AnatomyState
    @State private var input: String = ""

    public init(state: AnatomyState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("› device ready.")
                        .foregroundStyle(LCDPalette.textDim)
                        .font(Typography.systemMono(size: 12))
                    Text("› hilfer here. ask me anything.")
                        .foregroundStyle(LCDPalette.textAmber)
                        .font(Typography.chatBody(size: 14))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            HStack(spacing: 8) {
                Text("›").foregroundStyle(LCDPalette.textDim)
                TextField("type or tap sensors to speak…", text: $input)
                    .font(Typography.chatBody(size: 14))
                    .foregroundStyle(LCDPalette.textAmber)
                    .textFieldStyle(.plain)
                    .submitLabel(.send)
                    .onSubmit { sendMessage() }
            }
            .padding(10)
            .background(LCDPalette.chromeDark.opacity(0.5))
        }
        .background(LCDPalette.bgWarm)
    }

    private func sendMessage() {
        guard !input.isEmpty else { return }
        // TODO (Slice 4 follow-up): route through ConversationManager.
        // For now, the input is captured; b0tCore's ConversationManager integration
        // lives in HomeView so it can use the existing Bootstrap state from b0tApp.
        input = ""
    }
}

#Preview("chat — idle (default lcd)") {
    let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/preview"))
    let store = BotStore()
    let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
    return ChatView(state: state)
        .frame(maxHeight: 320)
        .background(Color.black)
}
