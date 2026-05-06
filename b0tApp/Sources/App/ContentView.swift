import SwiftUI
import b0tBrain
import b0tHome

struct ContentView: View {
    let bootstrap: Bootstrap

    #if DEBUG
        @State private var showDebugBrain = false
    #endif

    var body: some View {
        ZStack {
            switch bootstrap {
            case .pending:
                pendingView
            case .ready(let bot, let store):
                HomeView(bot: bot, store: store, initialHeartBPM: 4)
                    #if DEBUG
                        .onLongPressGesture(minimumDuration: 1.5) {
                            showDebugBrain = true
                        }
                    #endif
            case .failed(let reason):
                failedView(reason)
            }
        }
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

    private var pendingView: some View {
        VStack {
            Text("device starting…")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func failedView(_ reason: String) -> some View {
        VStack(spacing: 8) {
            Text("bootstrap failed")
                .font(.system(.caption, design: .monospaced))
            Text(reason)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView(bootstrap: .pending)
}
