import SwiftUI
import XCTest

import b0tBrain
import b0tFace

@testable import b0tHome

@MainActor
final class ChatFaceHeaderTests: XCTestCase {
    func test_chatFaceHeader_builds() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        _ = ChatFaceHeader(state: state)
    }

    func test_makeFaceScene_installsNamedFaceUnit() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        let scene = ChatFaceHeader.makeFaceScene(state: state)
        XCTAssertEqual(scene.headNode?.name, "face_unit")
        XCTAssertNotNil(scene.faceTapHandler)  // bridge connected → tap toggles mode
    }
}
