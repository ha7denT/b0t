import XCTest
import b0tBrain

@testable import b0tCore
@testable import b0tHome

@MainActor
final class AnatomyStateUsageTests: XCTestCase {
    func test_latestUsage_defaultsNil_andIsSettable() {
        let bot = Bot.empty(
            at: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let state = AnatomyState(bot: bot, store: BotStore(), initialHeartBPM: 60)
        XCTAssertNil(state.latestUsage)
        state.latestUsage = GenerationUsage(
            tokensIn: 100, tokensOut: 20, limit: 4000, modelId: "x", breakdown: [:])
        XCTAssertEqual(state.latestUsage?.tokensIn, 100)
    }
}
