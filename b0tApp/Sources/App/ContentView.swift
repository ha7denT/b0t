import SwiftUI
import b0tCore

struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("b0t")
                .font(.system(.largeTitle, design: .monospaced))
            Text("module: \(b0tCorePlaceholder.identifier)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
