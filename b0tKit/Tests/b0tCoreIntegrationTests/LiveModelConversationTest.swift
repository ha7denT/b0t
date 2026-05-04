import FoundationModels
import XCTest

@testable import b0tBrain
@testable import b0tCore

final class LiveModelConversationTest: XCTestCase {
    func test_oneConversationTurn_completesAgainstRealModel() async throws {
        try requireFoundationModelsAvailable()

        let bot = try await loadProductionDefaultBotInTempCopy()
        let store = BotStore()
        let client = try LiveLanguageModelClient()
        let manager = ConversationManager(bot: bot, store: store, client: client)

        let response = try await manager.respond(to: "say hi in one sentence")

        XCTAssertFalse(response.text.isEmpty, "expected a non-empty reply")

        // Journal entry written.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        let day = formatter.string(from: Date())
        let journalURL = bot.journal.directoryURL.appendingPathComponent("\(day).md")
        let journal = try String(contentsOf: journalURL, encoding: .utf8)
        XCTAssertTrue(journal.contains("turn 1"))
    }

    private func requireFoundationModelsAvailable() throws {
        guard SystemLanguageModel.default.isAvailable else {
            throw XCTSkip("Foundation Models is not available on this test runner")
        }
    }

    private func loadProductionDefaultBotInTempCopy() async throws -> Bot {
        // Repo-relative path: <this-file> → b0tCoreIntegrationTests/ → Tests/ → b0tKit/ → repo
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
