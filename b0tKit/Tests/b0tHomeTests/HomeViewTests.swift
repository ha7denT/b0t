import SwiftUI
import XCTest

import b0tBrain

@testable import b0tHome

@MainActor
final class HomeViewTests: XCTestCase {
    func test_homeView_buildsInChatMode() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        _ = HomeView(bot: bot, store: store, initialHeartBPM: 4)
        // Default mode is chat (Task 1). Construction must not crash.
    }
}
