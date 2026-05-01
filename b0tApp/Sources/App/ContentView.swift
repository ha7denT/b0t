import SwiftUI
import b0tBrain

struct ContentView: View {
    let bootstrap: Bootstrap

    #if DEBUG
        @State private var showDebugBrain = false
    #endif

    var body: some View {
        VStack(spacing: 8) {
            Text("b0t")
                .font(.system(.largeTitle, design: .monospaced))
            statusLine
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            #if DEBUG
                if case .ready = bootstrap {
                    Button("debug brain") { showDebugBrain = true }
                        .font(.system(.caption, design: .monospaced))
                        .padding(.top, 16)
                }
            #endif
        }
        .padding()
        #if DEBUG
            .sheet(isPresented: $showDebugBrain) {
                if case .ready(let bot, let store) = bootstrap {
                    NavigationStack {
                        DebugBrainView(bot: bot, store: store)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("close") { showDebugBrain = false }
                            }
                        }
                    }
                }
            }
        #endif
    }

    @ViewBuilder
    private var statusLine: some View {
        switch bootstrap {
        case .pending:
            Text("provisioning...")
        case .ready(let bot, _):
            Text("active: \(bot.rootURL.lastPathComponent)")
        case .failed(let reason):
            Text("bootstrap failed: \(reason)")
        }
    }
}

#Preview {
    ContentView(bootstrap: .pending)
}
