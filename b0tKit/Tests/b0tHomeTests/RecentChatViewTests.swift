import SwiftUI
import XCTest

import b0tBrain

@testable import b0tHome

@MainActor
final class RecentChatViewTests: XCTestCase {
    func test_recentChatView_builds() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        _ = RecentChatView(state: state)
    }

    func test_latestTurns_returnsLastTwoNonStatusTurns() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        state.transcript.append(ChatTurn(role: .user, text: "› a"))
        state.transcript.append(ChatTurn(role: .bot, text: "› b"))
        let view = RecentChatView(state: state)
        let turns = view.latestTurns
        XCTAssertEqual(turns.map(\.text).suffix(2), ["› a", "› b"])
        XCTAssertFalse(turns.contains { $0.role == .status })
    }

    func test_tapToReturn_setsChatMode() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        state.mode = .workbench
        let view = RecentChatView(state: state)
        view.returnToChat()
        XCTAssertEqual(state.mode, .chat)
    }
}
