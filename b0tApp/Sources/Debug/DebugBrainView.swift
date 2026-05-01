#if DEBUG
    import SwiftUI
    import b0tCore
    import b0tBrain

    struct DebugBrainView: View {
        let bot: Bot
        let store: BotStore

        @State private var input: String = ""
        @State private var log: [LogEntry] = []
        @State private var isThinking: Bool = false
        @State private var manager: ConversationManager?
        @State private var modelStatus: ModelStatus = .uninitialized

        private struct LogEntry: Identifiable {
            let id = UUID()
            let role: Role
            let text: String
            enum Role { case user, bot, status }
        }

        private enum ModelStatus {
            case uninitialized
            case live
            case stub(reason: String)
        }

        var body: some View {
            VStack(spacing: 0) {
                modelStatusBanner
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
                        .disabled(isThinking || manager == nil)
                        .onSubmit { Task { await send() } }
                    Button("send") { Task { await send() } }
                        .disabled(input.isEmpty || isThinking || manager == nil)
                }
                .padding()
            }
            .navigationTitle("debug brain")
            .task { await initializeManager() }
        }

        @ViewBuilder
        private var modelStatusBanner: some View {
            switch modelStatus {
            case .uninitialized:
                Text("initializing model...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            case .live:
                EmptyView()
            case .stub(let reason):
                Text("stub mode — \(reason)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }

        private func colour(for role: LogEntry.Role) -> Color {
            switch role {
            case .user: return .primary
            case .bot: return .accentColor
            case .status: return .secondary
            }
        }

        private func initializeManager() async {
            let forceStub = ProcessInfo.processInfo.arguments.contains("--use-stub-client")

            let client: any LanguageModelClient
            if forceStub {
                client = makeStub()
                modelStatus = .stub(reason: "--use-stub-client launch arg")
            } else {
                do {
                    client = try LiveLanguageModelClient()
                    modelStatus = .live
                } catch LanguageModelClientError.modelUnavailable {
                    client = makeStub()
                    modelStatus = .stub(reason: "model unavailable on this device")
                } catch {
                    client = makeStub()
                    modelStatus = .stub(reason: "init failed: \(error)")
                }
            }

            manager = ConversationManager(bot: bot, store: store, client: client)
        }

        private func makeStub() -> StubLanguageModelClient {
            StubLanguageModelClient { context, _ in
                ConversationResponse(text: "echo: \(context.userPrompt)")
            }
        }

        private func send() async {
            guard let manager else { return }
            let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty else { return }
            input = ""
            log.append(LogEntry(role: .user, text: "> \(prompt)"))
            isThinking = true
            defer { isThinking = false }

            do {
                let reply = try await manager.respond(to: prompt)
                log.append(LogEntry(role: .bot, text: reply.text))
            } catch {
                log.append(LogEntry(role: .status, text: "error: \(error)"))
            }
        }
    }
#endif
