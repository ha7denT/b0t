import SwiftUI
import b0tBrain

struct ContentView: View {
    let bootstrap: Bootstrap

    var body: some View {
        VStack(spacing: 8) {
            Text("b0t")
                .font(.system(.largeTitle, design: .monospaced))
            statusLine
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding()
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
