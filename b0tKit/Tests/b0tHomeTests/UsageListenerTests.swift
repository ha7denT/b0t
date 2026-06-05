import Combine
import XCTest
import b0tBrain

@testable import b0tCore
@testable import b0tHome

@MainActor
final class UsageListenerTests: XCTestCase {
    func test_listener_setsLatestUsageOnEvent() {
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
        XCTAssertEqual(state.latestUsage?.tokensOut, 40)
        listener.stop()
    }
}
