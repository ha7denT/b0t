import Combine
import XCTest

import b0tBrain
import b0tFace

@testable import b0tHome

@MainActor
final class ToolInvocationListenerTests: XCTestCase {
    func test_listener_pulsesToolsOrganOnGenericInvocation() {
        let state = makeState()
        let publisher = PassthroughSubject<String, Never>()
        let listener = ToolInvocationListener(state: state, source: publisher.eraseToAnyPublisher())
        listener.start()

        publisher.send("calendar.upcoming_events")

        XCTAssertTrue(state.activeWiring.contains(.tools))
    }

    func test_listener_routesMemoryToolsToMemoryOrgan() {
        let state = makeState()
        let publisher = PassthroughSubject<String, Never>()
        let listener = ToolInvocationListener(state: state, source: publisher.eraseToAnyPublisher())
        listener.start()

        publisher.send("memory.write")

        XCTAssertTrue(state.activeWiring.contains(.memory))
        XCTAssertFalse(state.activeWiring.contains(.tools))
    }

    func test_listener_stop_cancelsSubscription() {
        let state = makeState()
        let publisher = PassthroughSubject<String, Never>()
        let listener = ToolInvocationListener(state: state, source: publisher.eraseToAnyPublisher())
        listener.start()
        listener.stop()

        publisher.send("calendar.upcoming_events")

        XCTAssertFalse(state.activeWiring.contains(.tools))
    }

    private func makeState() -> AnatomyState {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        return AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
    }
}
