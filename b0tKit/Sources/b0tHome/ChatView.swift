import SwiftUI

import b0tBrain
import b0tCore
import b0tDesign

/// Default LCD content — chat scrollback and composer.
///
/// Reads `state.manager` for the active `ConversationManager`. Until the
/// manager is initialized (HomeView's .task), the composer is disabled and a
/// "device starting…" status line shows. After init, sending a message
/// invokes `manager.respond(to:)` and appends the response to the scrollback.
public struct ChatView: View {
    @Bindable var state: AnatomyState
    @State private var input: String = ""
    @State private var log: [LogEntry] = [
        LogEntry(role: .status, text: "› device ready."),
        LogEntry(role: .bot, text: "› hilfer here. ask me anything."),
    ]
    @State private var isThinking: Bool = false

    private struct LogEntry: Identifiable, Hashable {
        let id = UUID()
        let role: Role
        let text: String

        enum Role: Hashable { case user, bot, status, toolCall }
    }

    public init(state: AnatomyState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(log) { entry in
                            entryView(for: entry)
                                .id(entry.id)
                        }
                        if isThinking {
                            Text("…")
                                .foregroundStyle(LCDPalette.textDim)
                                .font(Typography.systemMono(size: 12))
                                .id("thinking")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                .onChange(of: log.count) { _, _ in
                    if let last = log.last {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                Text("›").foregroundStyle(LCDPalette.textDim)
                TextField(composerPlaceholder, text: $input)
                    .font(Typography.chatBody(size: 14))
                    .foregroundStyle(LCDPalette.textAmber)
                    .textFieldStyle(.plain)
                    .submitLabel(.send)
                    .disabled(state.manager == nil || isThinking)
                    .onSubmit { Task { await sendMessage() } }
            }
            .padding(10)
            .background(LCDPalette.chromeDark.opacity(0.5))
        }
        .background(LCDPalette.bgWarm)
    }

    @ViewBuilder
    private func entryView(for entry: LogEntry) -> some View {
        switch entry.role {
        case .user:
            Text(entry.text)
                .foregroundStyle(LCDPalette.textAmber)
                .font(Typography.chatBody(size: 14))
        case .bot:
            Text(entry.text)
                .foregroundStyle(LCDPalette.textAmber)
                .font(Typography.chatBody(size: 14))
        case .status:
            Text(entry.text)
                .foregroundStyle(LCDPalette.textDim)
                .font(Typography.systemMono(size: 12))
        case .toolCall:
            Text(entry.text)
                .foregroundStyle(LCDPalette.textDim)
                .font(Typography.systemMono(size: 11))
        }
    }

    private var composerPlaceholder: String {
        if state.manager == nil { return "device starting…" }
        if isThinking { return "thinking…" }
        return "type or tap sensors to speak…"
    }

    private func sendMessage() async {
        guard let manager = state.manager else { return }
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        input = ""
        log.append(LogEntry(role: .user, text: "› \(prompt)"))
        isThinking = true
        defer { isThinking = false }

        do {
            let turn = try await manager.respond(to: prompt)
            for record in turn.toolCalls {
                log.append(
                    LogEntry(
                        role: .toolCall,
                        text: "  → \(record.toolName)"
                    ))
            }
            log.append(LogEntry(role: .bot, text: turn.response.text))
        } catch {
            log.append(LogEntry(role: .status, text: "— error: \(error)"))
        }
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
