import SwiftUI
import XCTest

import b0tBrain

@testable import b0tHome

final class ChatViewTests: XCTestCase {
    func test_chatView_buildsForInspection() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        _ = ChatView(state: state)
        // No assertion — compile + construct is the test surface.
    }
}
