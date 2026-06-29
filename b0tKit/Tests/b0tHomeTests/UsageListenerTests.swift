import Combine
import XCTest
import b0tBrain

@testable import b0tCore
@testable import b0tHome

@MainActor
final class UsageListenerTests: XCTestCase {
    func test_listener_setsLatestUsageOnEvent() async {
        let bot = Bot.empty(
            at: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString))
        let state = AnatomyState(bot: bot, store: BotStore(), initialHeartBPM: 60)
        let subject = PassthroughSubject<GenerationUsage, Never>()
        let listener = UsageListener(state: state, source: subject.eraseToAnyPublisher())
        listener.start()
        subject.send(
            GenerationUsage(
                tokensIn: 200, tokensOut: 40, limit: 4000, modelId: "qwen3-1.7b", breakdown: [:]))
        // The listener now hops to MainActor asynchronously (it no longer assumes
        // the sender is already on main), so await the state mutation.
        await pollUntil { state.latestUsage?.tokensOut == 40 }
        XCTAssertEqual(state.latestUsage?.tokensOut, 40)
        listener.stop()
    }

    /// Yields the MainActor until `condition` holds or the cap is hit, so an
    /// asynchronously-applied @Observable mutation becomes visible.
    private func pollUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(nanoseconds: 1_000_000)  // 1ms
        }
    }
}
