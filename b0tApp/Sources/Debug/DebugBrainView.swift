#if DEBUG
    import SwiftUI
    import b0tCore
    import b0tBrain

    /// A throwaway debug surface for Phase 2 development.
    ///
    /// Only compiled in DEBUG builds. Phase 4 replaces this with the real
    /// anatomical GUI. Until then this view is the only surface that exercises
    /// `ConversationManager` and (later) `HeartbeatManager` end-to-end on a
    /// running app.
    ///
    /// Slice 1 (this file): chat field + scrolling reply log, stub client only.
    /// Slice 2 (Task 11): switch to `LiveLanguageModelClient` with stub fallback.
    /// Slice 4 (Task 17): journal-tail pane.
    /// Slice 5 (Task 22): "fire heartbeat now" button.
    struct DebugBrainView: View {
        let bot: Bot
        let store: BotStore

        @State private var input: String = ""
        @State private var log: [LogEntry] = []
        @State private var isThinking: Bool = false

        private struct LogEntry: Identifiable {
            let id = UUID()
            let role: Role
            let text: String
            enum Role { case user, bot, status }
        }

        var body: some View {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(log) { entry in
                            Text(entry.text)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(colour(for: entry.role))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
                Divider()
                HStack {
                    TextField("message", text: $input)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isThinking)
                        .onSubmit { Task { await send() } }
                    Button("send") { Task { await send() } }
                        .disabled(input.isEmpty || isThinking)
                }
                .padding()
            }
            .navigationTitle("debug brain")
        }

        private func colour(for role: LogEntry.Role) -> Color {
            switch role {
            case .user: return .primary
            case .bot: return .accentColor
            case .status: return .secondary
            }
        }

        private func send() async {
            let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty else { return }
            input = ""
            log.append(LogEntry(role: .user, text: "> \(prompt)"))
            isThinking = true
            defer { isThinking = false }

            let stub = StubLanguageModelClient { context, _ in
                ConversationResponse(text: "echo: \(context.userPrompt)")
            }
            let manager = ConversationManager(bot: bot, store: store, client: stub)

            do {
                let reply = try await manager.respond(to: prompt)
                log.append(LogEntry(role: .bot, text: reply.text))
            } catch {
                log.append(LogEntry(role: .status, text: "error: \(error)"))
            }
        }
    }
#endif
