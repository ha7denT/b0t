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
                MemoryObservation(about: "Hayden", what: "vendor call at 4pm", importance: .high),
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
        XCTAssertTrue(recent.prose.contains("Hayden"))
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

    func test_apply_tickDecision_capturesWouldNotifyText() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()
        let executor = Executor(bot: bot, store: store)

        let decision = TickDecision(
            observed: "deadline approaching",
            considered: ["pass", "notify_user"],
            decided: "notify_user",
            why: "deadline within 30 minutes",
            acted: "post to chat: vendor call in 30 minutes",
            mood: .attentive
        )
        let delta = try await executor.apply(decision)

        XCTAssertEqual(delta.wouldNotifyText, "post to chat: vendor call in 30 minutes")
    }

    func test_apply_tickDecision_silentActedDoesNotCaptureNotify() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()
        let executor = Executor(bot: bot, store: store)

        let decision = TickDecision(
            observed: "afternoon",
            considered: ["pass"],
            decided: "pass",
            why: "nothing urgent",
            acted: "noted silently"
        )
        let delta = try await executor.apply(decision)

        XCTAssertNil(delta.wouldNotifyText)
    }

    func test_apply_tickDecision_respectsNotificationBudget() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()

        // canonical-bot's actions.md sets notification_budget_per_day: 5.
        // Pre-populate today's journal with 5 'would_notify' entries to exhaust the budget.
        let dayString = makeDayString(for: Date())
        let journalURL = bot.journal.directoryURL.appendingPathComponent("\(dayString).md")
        try FileManager.default.createDirectory(
            at: bot.journal.directoryURL, withIntermediateDirectories: true
        )
        var preexisting = "---\ndate: \(dayString)\n---\n\n"
        for i in 1...5 {
            preexisting += """
                ## 0\(i):00 \u{2014} heartbeat \(i)

                **observed:** synthetic
                **considered:** notify_user
                **decided:** notify_user
                **why:** synthetic
                **acted:** post to chat: synthetic
                **state_delta:** would_notify: post to chat: synthetic


                """
        }
        try Data(preexisting.utf8).write(to: journalURL, options: [.atomic])

        let executor = Executor(bot: bot, store: store)
        let decision = TickDecision(
            observed: "deadline approaching",
            considered: ["pass", "notify_user"],
            decided: "notify_user",
            why: "deadline within 30 minutes",
            acted: "post to chat: vendor call in 30 minutes"
        )
        let delta = try await executor.apply(decision)

        // Budget exhausted — wouldNotifyText must NOT be captured.
        XCTAssertNil(delta.wouldNotifyText, "budget exhausted, should not capture")
    }

    private func makeDayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        return formatter.string(from: date)
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
