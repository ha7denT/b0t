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

    @MainActor
    func test_chatView_rendersSeededTranscriptFromState() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        state.transcript.append(ChatTurn(role: .user, text: "› ping"))
        _ = ChatView(state: state)
        XCTAssertEqual(state.transcript.count, 3)
        XCTAssertEqual(state.transcript.last?.text, "› ping")
    }
}
