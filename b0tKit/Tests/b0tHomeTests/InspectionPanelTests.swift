import SwiftUI
import XCTest

import b0tBrain
import b0tFace

@testable import b0tHome

@MainActor
final class InspectionPanelTests: XCTestCase {
    func test_panelInitialises_withNoOrganSelected() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        _ = InspectionPanel(state: state)
        XCTAssertNil(state.selectedOrgan)
    }

    func test_panelInitialises_withOrganSelected() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        state.selectedOrgan = .memory
        _ = InspectionPanel(state: state)
        XCTAssertEqual(state.selectedOrgan, .memory)
    }

    func test_panel_zeroState_offersReturnToChat() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        state.mode = .workbench
        state.selectedOrgan = nil
        // The panel's nil-organ branch is RecentChatView; tapping its return
        // affordance sets chat mode. Drive the same state mutation it performs.
        RecentChatView(state: state).returnToChat()
        XCTAssertEqual(state.mode, .chat)
    }
}
