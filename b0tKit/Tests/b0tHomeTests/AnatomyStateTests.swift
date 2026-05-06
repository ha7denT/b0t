import XCTest

import b0tBrain
import b0tFace

@testable import b0tHome

final class AnatomyStateTests: XCTestCase {
    func test_initialState_hasNoSelectedOrgan() {
        let state = makeState()
        XCTAssertNil(state.selectedOrgan)
    }

    func test_initialState_hasEmptyActiveWiring() {
        let state = makeState()
        XCTAssertTrue(state.activeWiring.isEmpty)
    }

    func test_selectingOrgan_setsSelectedOrgan() {
        let state = makeState()
        state.selectedOrgan = .memory
        XCTAssertEqual(state.selectedOrgan, .memory)
    }

    func test_addingActiveWiring_includesIt() {
        let state = makeState()
        state.activeWiring.insert(.tools)
        XCTAssertTrue(state.activeWiring.contains(.tools))
    }

    func test_heartBPM_isMutable() {
        let state = makeState()
        state.heartBPM = 8
        XCTAssertEqual(state.heartBPM, 8)
    }

    private func makeState() -> AnatomyState {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        return AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
    }
}
