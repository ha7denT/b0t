import FoundationModels
import XCTest

@testable import b0tBrain
@testable import b0tCore

final class ConversationManagerTests: XCTestCase {
    func test_respond_buildsAssembledContextFromBot_passesToClient() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()
        let stub = StubLanguageModelClient { context, _ in
            // Real context now: instructions reference the bot, prompt carries the user message.
            XCTAssertTrue(
                context.systemInstructions.contains("b0t-fixture"),
                "expected b0t_name from identity/core.md frontmatter in instructions")
            XCTAssertTrue(context.userPrompt.contains("hello"))
            XCTAssertGreaterThan(context.budget.estimated, 0)
            return ConversationResponse(text: "echo: hello")
        }
        let manager = ConversationManager(bot: bot, store: store, client: stub)

        let response = try await manager.respond(to: "hello")

        XCTAssertEqual(response.text, "echo: hello")
    }

    func test_respond_appliesMemoryObservations_persistsAcrossTurns() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()

        // Swift 6 strict concurrency: the Handler closure is @Sendable, so we
        // cannot capture a plain `var turn = 0`. Use a reference-type counter
        // marked @unchecked Sendable (the mutation is serialised by the test's
        // sequential await chain, so it is safe in practice).
        final class TurnCounter: @unchecked Sendable { var n = 0 }
        let counter = TurnCounter()

        let stub = StubLanguageModelClient { context, _ in
            counter.n += 1
            if counter.n == 1 {
                return ConversationResponse(
                    text: "noted",
                    memoryObservations: [
                        MemoryObservation(
                            about: "Jamee",
                            what: "has a vendor call at 4pm",
                            importance: .high
                        )
                    ]
                )
            } else {
                // Second turn: assert the assembler picked up the observation
                // from memory/recent.md (which was written by the first turn).
                XCTAssertTrue(
                    context.systemInstructions.contains("vendor call at 4pm"),
                    "second turn's instructions should include the first turn's observation"
                )
                return ConversationResponse(text: "remembered")
            }
        }
        let manager = ConversationManager(bot: bot, store: store, client: stub)

        _ = try await manager.respond(to: "I have a vendor call at 4 today")
        let second = try await manager.respond(to: "what's on my calendar?")
        XCTAssertEqual(second.text, "remembered")
    }

    func test_respond_appendsJournalEntryPerTurn() async throws {
        let bot = try await loadCanonicalBotInTempCopy()
        let store = BotStore()

        let stub = StubLanguageModelClient { _, _ in
            ConversationResponse(text: "hello back")
        }
        let manager = ConversationManager(bot: bot, store: store, client: stub)

        _ = try await manager.respond(to: "hi")
        _ = try await manager.respond(to: "anything new?")

        // Find today's journal file. The fixture may contain older .md files;
        // filter to only the file JournalWriter would create for today (UTC).
        let journalDir = bot.journal.directoryURL
        let entries = try FileManager.default.contentsOfDirectory(
            at: journalDir,
            includingPropertiesForKeys: nil
        )
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .iso8601)
        let todayString = formatter.string(from: Date())
        let mdFiles = entries.filter {
            $0.pathExtension == "md" && $0.deletingPathExtension().lastPathComponent == todayString
        }
        XCTAssertEqual(mdFiles.count, 1, "exactly one journal file should exist for today")

        let content = try String(contentsOf: mdFiles[0], encoding: .utf8)
        XCTAssertTrue(content.contains("turn 1"), "first turn should be numbered 1")
        XCTAssertTrue(content.contains("turn 2"), "second turn should be numbered 2")
        XCTAssertTrue(content.contains("user said: hi"))
        XCTAssertTrue(content.contains("user said: anything new?"))
    }

    // MARK: – Helpers

    /// Copies the read-only bundle fixture to a temp directory so tests that
    /// mutate files (e.g. writing memory/recent.md) don't corrupt the bundle.
    private func loadCanonicalBotInTempCopy() async throws -> Bot {
        let source = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/canonical-bot")
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: source, to: temp)
        addTeardownBlock { try? FileManager.default.removeItem(at: temp) }
        let store = BotStore()
        return try await store.load(at: temp)
    }
}
