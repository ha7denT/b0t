import XCTest
import b0tBrain

@testable import b0tModules

final class DefaultBotModulesTests: XCTestCase {
    /// Phase 3 Acceptance Criterion #9 (spec §10).
    ///
    /// The production `default-bot/` directory ships 10 module markdown
    /// files. Phase 3 backs 4 with native bridges. Of those, `health.md`
    /// is `enabled: false` by default — health is opt-in.
    ///
    /// Result: 3 instantiated (calendar, reminders, time-awareness),
    /// 6 unknown-and-skipped (journaling, location, mail, notes,
    /// onboarding, weather), 1 disabled-and-skipped (health).
    func testRegistryLoadsThreeKnownModulesFromProductionDefaultBot() async throws {
        // The default-bot/ directory lives at the repository root, three
        // levels up from this source file.

        let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

        let defaultBotURL =
            here
            .appendingPathComponent("../../../default-bot", isDirectory: true)
            .standardizedFileURL

        let store = BotStore()
        let bot = try await store.load(at: defaultBotURL)

        let modules = try await ModuleRegistry.loadModules(for: bot)

        let ids = Set(modules.map { type(of: $0).id })
        let expected: Set<String> = ["calendar", "reminders", "time-awareness"]
        XCTAssertEqual(
            ids,
            expected,
            "Phase 3 should load exactly calendar, reminders, time-awareness from default-bot/. health.md is enabled:false. Mail/Location/Notes/Weather/Journaling/Onboarding are unknown-and-skipped."
        )
        XCTAssertEqual(modules.count, 3)
    }
}
