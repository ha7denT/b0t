import FoundationModels
import XCTest

@testable import b0tBrain
@testable import b0tCore

final class ExecutorTests: XCTestCase {
    func test_apply_writesMediumAndHighImportanceObservationsToMemoryRecent() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()
        let executor = Executor(bot: bot, store: store)

        let response = ConversationResponse(
            text: "noted",
            memoryObservations: [
                MemoryObservation(about: "Jamee", what: "vendor call at 4pm", importance: .high),
                MemoryObservation(about: "weather", what: "looks like rain", importance: .low),
                MemoryObservation(
                    about: "work_tracker", what: "deadline tomorrow", importance: .medium),
            ]
        )

        let delta = try await executor.apply(response)

        XCTAssertEqual(
            delta.writtenFiles.count, 1, "exactly one file should be written: memory/recent.md")
        XCTAssertNil(delta.wouldNotifyText)

        // Re-read memory/recent.md and confirm the medium and high observations are present.
        let recent = try await bot.memory.recent
        XCTAssertTrue(recent.prose.contains("Jamee"))
        XCTAssertTrue(recent.prose.contains("vendor call at 4pm"))
        XCTAssertTrue(recent.prose.contains("work_tracker"))
        XCTAssertTrue(recent.prose.contains("deadline tomorrow"))
        XCTAssertFalse(
            recent.prose.contains("looks like rain"),
            ".low importance must not be persisted")
    }

    func test_apply_emptyObservations_writesNothing() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()
        let executor = Executor(bot: bot, store: store)

        let response = ConversationResponse(text: "noted", memoryObservations: [])
        let delta = try await executor.apply(response)

        XCTAssertTrue(delta.writtenFiles.isEmpty)
        XCTAssertNil(delta.wouldNotifyText)
    }

    func test_apply_observationsAreNewestFirst() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()
        let executor = Executor(bot: bot, store: store)

        // Apply two responses; the second's observation should appear before the first's
        // in memory/recent.md.
        _ = try await executor.apply(
            ConversationResponse(
                text: "first",
                memoryObservations: [
                    MemoryObservation(about: "topic", what: "first observation", importance: .high)
                ]
            ))
        _ = try await executor.apply(
            ConversationResponse(
                text: "second",
                memoryObservations: [
                    MemoryObservation(
                        about: "topic", what: "second observation", importance: .high)
                ]
            ))

        let recent = try await bot.memory.recent
        let firstIndex = recent.prose.range(of: "first observation")!.lowerBound
        let secondIndex = recent.prose.range(of: "second observation")!.lowerBound
        XCTAssertLessThan(
            secondIndex, firstIndex,
            "newest observation should appear first")
    }

    private func loadCanonicalBotInTempCopy() async throws -> Bot {
        let fixture =
            Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/canonical-bot")
        let temp =
            FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: fixture, to: temp)
        addTeardownBlock { try? FileManager.default.removeItem(at: temp) }
        let store = BotStore()
        return try await store.load(at: temp)
    }
}
