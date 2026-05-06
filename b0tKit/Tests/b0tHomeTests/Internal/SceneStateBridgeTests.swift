import XCTest

import b0tBrain
import b0tFace

@testable import b0tHome

@MainActor
final class SceneStateBridgeTests: XCTestCase {
    func test_bridge_setsSelectedOrganOnTap() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        SceneStateBridge.connect(scene: scene, state: state)

        scene.tapHandler?(.memory)
        XCTAssertEqual(state.selectedOrgan, .memory)
    }

    func test_bridge_secondTapOnSameOrgan_deselects() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        SceneStateBridge.connect(scene: scene, state: state)

        scene.tapHandler?(.memory)  // select
        scene.tapHandler?(.memory)  // deselect
        XCTAssertNil(state.selectedOrgan)
    }
}
