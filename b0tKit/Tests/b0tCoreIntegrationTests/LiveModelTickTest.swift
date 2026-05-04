import FoundationModels
import XCTest

@testable import b0tBrain
@testable import b0tCore

final class LiveModelTickTest: XCTestCase {
    func test_oneHeartbeatTick_completesAgainstRealModel() async throws {
        try requireFoundationModelsAvailable()

        let bot = try await loadProductionDefaultBotInTempCopy()
        let store = BotStore()
        let client = try LiveLanguageModelClient()
        let manager = HeartbeatManager(bot: bot, store: store, client: client)

        let result = try await manager.tick(trigger: .manual)

        switch result {
        case .decided(let d, _, _):
            XCTAssertFalse(d.observed.isEmpty)
            XCTAssertFalse(d.decided.isEmpty)
        case .suppressed(let reason):
            // .quietHours is plausible if the test runs during the canonical quiet window.
            XCTAssertEqual(reason, .quietHours, "model unavailable but available check passed?")
        case .errored(let msg):
            XCTFail("tick errored: \(msg)")
        }
    }

    private func requireFoundationModelsAvailable() throws {
        guard SystemLanguageModel.default.isAvailable else {
            throw XCTSkip("Foundation Models is not available on this test runner")
        }
    }

    private func loadProductionDefaultBotInTempCopy() async throws -> Bot {
        let here = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let defaultBot = here.appendingPathComponent("default-bot")
        let parentTemp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let temp = parentTemp.appendingPathComponent("b0t-01")
        try FileManager.default.createDirectory(at: parentTemp, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: defaultBot, to: temp)
        addTeardownBlock { try? FileManager.default.removeItem(at: parentTemp) }

        let store = BotStore()
        return try await store.load(at: temp)
    }
}
