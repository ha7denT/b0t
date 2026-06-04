#if DEBUG
    import SwiftUI
    import b0tCore
    import b0tBrain
    import b0tModules

    struct DebugBrainView: View {
        let bot: Bot
        let store: BotStore

        @State private var input: String = ""
        @State private var log: [LogEntry] = []
        @State private var isThinking: Bool = false
        @State private var manager: ConversationManager?
        @State private var modelStatus: ModelStatus = .uninitialized
        @State private var journalTail: String = ""
        @State private var heartbeat: HeartbeatManager?
        @State private var isHeartbeating: Bool = false

        private struct LogEntry: Identifiable {
            let id = UUID()
            let role: Role
            let text: String
            enum Role { case user, bot, status, toolCall }
        }

        private enum ModelStatus {
            case uninitialized
            case live
            case stub(reason: String)
        }

        var body: some View {
            VStack(spacing: 0) {
                modelStatusBanner
                HStack(alignment: .top, spacing: 0) {
                    chatPane
                        .frame(maxWidth: .infinity)
                    Divider()
                    journalPane
                        .frame(maxWidth: .infinity)
                }
                Divider()
                HStack {
                    TextField("message", text: $input)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isThinking || manager == nil)
                        .onSubmit { Task { await send() } }
                    Button("send") { Task { await send() } }
                        .disabled(input.isEmpty || isThinking || manager == nil)
                    Button("\u{2665}") { Task { await fireHeartbeat() } }
                        .disabled(isHeartbeating || heartbeat == nil)
                        .help("fire heartbeat now")
                }
                .padding()
            }
            .navigationTitle("debug brain")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink("Q6") { Q6ValidationView() }
                }
            }
            .task { await initializeManager() }
            .task { await pollJournalTail() }
        }

        @ViewBuilder
        private var modelStatusBanner: some View {
            switch modelStatus {
            case .uninitialized:
                Text("initializing model.")
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

        private var chatPane: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(log) { entry in
                        Text(entry.text)
                            .font(
                                entry.role == .toolCall
                                    ? .system(.caption, design: .monospaced)
                                    : .system(.body, design: .monospaced)
                            )
                            .foregroundStyle(colour(for: entry.role))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
        }

        private var journalPane: some View {
            ScrollView {
                Text(journalTail.isEmpty ? "(journal empty)" : journalTail)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }

        private func colour(for role: LogEntry.Role) -> Color {
            switch role {
            case .user: return .primary
            case .bot: return .accentColor
            case .status: return .secondary
            case .toolCall: return .secondary.opacity(0.7)
            }
        }

        private func initializeManager() async {
            let forceStub = ProcessInfo.processInfo.arguments.contains("--use-stub-client")

            let client: any LanguageModelClient
            if forceStub {
                client = makeStub()
                modelStatus = .stub(reason: "--use-stub-client launch arg.")
            } else {
                do {
                    client = try LiveLanguageModelClient()
                    modelStatus = .live
                } catch LanguageModelClientError.modelUnavailable {
                    client = makeStub()
                    modelStatus = .stub(reason: "model unavailable on this device.")
                } catch {
                    client = makeStub()
                    modelStatus = .stub(reason: "init failed: \(error).")
                }
            }

            let modules: [any Module]
            do {
                modules = try await ModuleRegistry.loadModules(for: bot)
                print(
                    "[b0t] loaded \(modules.count) modules: \(modules.map { type(of: $0).id })"
                )
            } catch {
                print("[b0t] ModuleRegistry.loadModules threw: \(error)")
                modules = []
            }
            let tools = modules.flatMap(\.tools)
            let toolsRequirePermission = modules.contains { !$0.requiredPermissions.isEmpty }

            manager = ConversationManager(
                bot: bot,
                store: store,
                client: client,
                tools: tools,
                toolsRequirePermission: toolsRequirePermission
            )
            heartbeat = HeartbeatManager(
                bot: bot,
                store: store,
                client: client,
                tools: tools,
                toolsRequirePermission: toolsRequirePermission
            )
        }

        private func makeStub() -> StubLanguageModelClient {
            StubLanguageModelClient { context, outputType in
                if outputType == ConversationResponse.self {
                    return ConversationResponse(text: "echo: \(context.userPrompt)")
                } else if outputType == TickDecision.self {
                    return TickDecision(
                        observed: "manual tick",
                        considered: ["pass"],
                        decided: "pass",
                        why: "stub mode",
                        acted: "noted silently"
                    )
                } else {
                    preconditionFailure("stub does not handle \(outputType)")
                }
            }
        }

        private func pollJournalTail() async {
            while !Task.isCancelled {
                await refreshJournalTail()
                try? await Task.sleep(for: .seconds(1))
            }
        }

        private func refreshJournalTail() async {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .iso8601)
            let day = formatter.string(from: Date())
            let url = bot.journal.directoryURL.appendingPathComponent("\(day).md")
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                // Keep the last ~3000 characters — enough to show several entries.
                if content.count <= 3000 {
                    journalTail = content
                } else {
                    let suffix = content.suffix(3000)
                    journalTail = "...\n" + String(suffix)
                }
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
                let turn = try await manager.respond(to: prompt)
                for record in turn.toolCalls {
                    log.append(
                        LogEntry(
                            role: .toolCall,
                            text:
                                "  \u{2192} \(record.toolName)(\(record.argumentsSummary))\n  \u{2190} \(record.outputSummary)"
                        ))
                }
                log.append(LogEntry(role: .bot, text: turn.response.text))
                await refreshJournalTail()
            } catch LanguageModelClientError.modelUnavailable {
                log.append(LogEntry(role: .status, text: "model unavailable on this device."))
            } catch {
                log.append(LogEntry(role: .status, text: "error: \(error)"))
            }
        }

        private func fireHeartbeat() async {
            guard let heartbeat else { return }
            isHeartbeating = true
            defer { isHeartbeating = false }
            log.append(LogEntry(role: .status, text: "\u{2665} firing heartbeat."))
            do {
                let result = try await heartbeat.tick(trigger: .manual)
                switch result {
                case .decided(let d, _, let toolCalls):
                    for record in toolCalls {
                        log.append(
                            LogEntry(
                                role: .toolCall,
                                text:
                                    "  \u{2192} \(record.toolName)(\(record.argumentsSummary))\n  \u{2190} \(record.outputSummary)"
                            ))
                    }
                    log.append(LogEntry(role: .status, text: "\u{2665} \(d.decided): \(d.acted)"))
                case .suppressed(let reason):
                    log.append(LogEntry(role: .status, text: "\u{2665} suppressed (\(reason.rawValue))"))
                case .errored(let msg):
                    log.append(LogEntry(role: .status, text: "\u{2665} errored: \(msg)"))
                }
                await refreshJournalTail()
            } catch {
                log.append(LogEntry(role: .status, text: "\u{2665} tick threw: \(error)"))
            }
        }
    }
#endif
