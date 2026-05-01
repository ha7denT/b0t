import SwiftUI
import b0tBrain

@main
struct b0tApp: App {
    @State private var bootstrap: Bootstrap = .pending

    var body: some Scene {
        WindowGroup {
            ContentView(bootstrap: bootstrap)
                .task {
                    bootstrap = await Bootstrap.run()
                }
        }
    }
}

enum Bootstrap: Sendable {
    case pending
    case ready(Bot, store: BotStore)
    case failed(String)

    static func run() async -> Bootstrap {
        do {
            let documents = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let active = try BotProvisioner.ensureDefaultBotProvisioned(
                documentsURL: documents,
                bundle: .main
            )
            let store = BotStore()
            let bot = try await store.load(at: active)
            return .ready(bot, store: store)
        } catch {
            return .failed(String(describing: error))
        }
    }
}
