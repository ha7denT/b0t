import SwiftUI
import b0tBrain
import b0tHome

struct ContentView: View {
    let bootstrap: Bootstrap
    let processorRuntime: ProcessorRuntime?

    #if DEBUG
        @State private var showDebugBrain = false
    #endif

    var body: some View {
        ZStack {
            switch bootstrap {
            case .pending:
                pendingView
            case .ready(let bot, let store):
                if let rt = processorRuntime {
                    HomeView(
                        bot: bot, store: store, initialHeartBPM: 4,
                        client: rt.engineHost,
                        modelIdProvider: { [host = rt.engineHost] in host.activeModelId },
                        processorController: rt.processorController,
                        downloadCoordinator: rt.downloadCoordinator
                    )
                    #if DEBUG
                        .onLongPressGesture(minimumDuration: 1.5) {
                            showDebugBrain = true
                        }
                    #endif
                } else {
                    // Runtime not yet built (brief startup window before
                    // ProcessorRuntime.make completes). Never render HomeView
                    // without the shared host in production.
                    pendingView
                }
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
    ContentView(bootstrap: .pending, processorRuntime: nil)
}
