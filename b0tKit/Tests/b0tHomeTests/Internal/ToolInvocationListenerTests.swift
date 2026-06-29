import Combine
import XCTest

import b0tBrain
import b0tFace

@testable import b0tHome

@MainActor
final class ToolInvocationListenerTests: XCTestCase {
    func test_listener_pulsesToolsOrganOnGenericInvocation() async {
        let state = makeState()
        let publisher = PassthroughSubject<String, Never>()
        let listener = ToolInvocationListener(state: state, source: publisher.eraseToAnyPublisher())
        listener.start()

        publisher.send("calendar.upcoming_events")

        // The listener now hops to MainActor asynchronously, so await the pulse.
        await pollUntil { state.activeWiring.contains(.tools) }
        XCTAssertTrue(state.activeWiring.contains(.tools))
    }

    func test_listener_routesMemoryToolsToMemoryOrgan() async {
        let state = makeState()
        let publisher = PassthroughSubject<String, Never>()
        let listener = ToolInvocationListener(state: state, source: publisher.eraseToAnyPublisher())
        listener.start()

        publisher.send("memory.write")

        await pollUntil { state.activeWiring.contains(.memory) }
        XCTAssertTrue(state.activeWiring.contains(.memory))
        XCTAssertFalse(state.activeWiring.contains(.tools))
    }

    func test_listener_stop_cancelsSubscription() async {
        let state = makeState()
        let publisher = PassthroughSubject<String, Never>()
        let listener = ToolInvocationListener(state: state, source: publisher.eraseToAnyPublisher())
        listener.start()
        listener.stop()

        publisher.send("calendar.upcoming_events")

        // Give any erroneously-scheduled hop a chance to run, then assert nothing fired.
        for _ in 0..<20 { try? await Task.sleep(nanoseconds: 1_000_000) }
        XCTAssertFalse(state.activeWiring.contains(.tools))
    }

    /// Yields until `condition` holds or the cap is hit, so an
    /// asynchronously-applied @Observable mutation becomes visible.
    private func pollUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(nanoseconds: 1_000_000)  // 1ms
        }
    }

    private func makeState() -> AnatomyState {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        return AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
    }
}
