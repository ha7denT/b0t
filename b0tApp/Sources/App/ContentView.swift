import SwiftUI
import b0tCore

struct ContentView: View {
    @State private var bundleStatus: String = "stand by."

    var body: some View {
        VStack(spacing: 8) {
            Text("b0t")
                .font(.system(.largeTitle, design: .monospaced))
            Text("module: \(b0tCorePlaceholder.identifier)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("default-bot: \(bundleStatus)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding()
        .task { bundleStatus = checkDefaultBotBundled() }
    }

    private func checkDefaultBotBundled() -> String {
        guard
            let url = Bundle.main.url(
                forResource: "core",
                withExtension: "md",
                subdirectory: "default-bot/identity"
            )
        else {
            return "not found."
        }
        return "bundled. \(url.lastPathComponent)"
    }
}

#Preview {
    ContentView()
}
