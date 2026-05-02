import FoundationModels
import XCTest
@testable import b0tBrain
@testable import b0tCore

final class HeartbeatScheduleTests: XCTestCase {
    func test_parse_canonicalScheduleFile_extractsAllFields() async throws {
        let bot = try await loadCanonicalBot()
        let scheduleFile = try await bot.heartbeat.schedule
        let schedule = try HeartbeatSchedule.parse(scheduleFile)

        XCTAssertEqual(schedule.bpm, 30)
        XCTAssertNotNil(schedule.quietHours)
        XCTAssertEqual(schedule.quietHours?.lowerBound, ClockTime(hour: 22, minute: 0))
        XCTAssertEqual(schedule.quietHours?.upperBound, ClockTime(hour: 6, minute: 30))
        // Verify overnight range is stored correctly (lowerBound > upperBound is allowed).
        XCTAssertGreaterThan(schedule.quietHours!.lowerBound, schedule.quietHours!.upperBound)
        XCTAssertEqual(
            schedule.eventTriggers,
            Set([
                .locationChangeSignificant,
                .calendarEventApproaching30min,
                .appForegrounded,
                .notificationReceived,
            ]))
        XCTAssertTrue(schedule.mutable)
    }

    func test_bpmInterval_isFifteenMinutes_at_BPM_30() {
        let schedule = HeartbeatSchedule(
            bpm: 30,
            quietHours: nil,
            eventTriggers: [],
            mutable: true
        )
        XCTAssertEqual(schedule.bpmInterval, .seconds(30 * 60))
    }

    func test_bpmInterval_isNil_at_BPM_0() {
        let schedule = HeartbeatSchedule(
            bpm: 0, quietHours: nil, eventTriggers: [], mutable: true
        )
        XCTAssertNil(schedule.bpmInterval)
    }

    func test_isQuietHours_normalRange_dayStart() {
        let schedule = HeartbeatSchedule(
            bpm: 30,
            quietHours: ClockTime(hour: 9, minute: 0)...ClockTime(hour: 17, minute: 0),
            eventTriggers: [], mutable: true
        )
        let inside = makeDate(year: 2026, month: 5, day: 1, hour: 10, minute: 30)
        let before = makeDate(year: 2026, month: 5, day: 1, hour: 8, minute: 0)
        let after = makeDate(year: 2026, month: 5, day: 1, hour: 17, minute: 1)
        XCTAssertTrue(schedule.isQuietHours(at: inside))
        XCTAssertFalse(schedule.isQuietHours(at: before))
        XCTAssertFalse(schedule.isQuietHours(at: after))
    }

    func test_isQuietHours_overnight_range() {
        let schedule = HeartbeatSchedule(
            bpm: 30,
            quietHours: ClockTime(hour: 22, minute: 0)...ClockTime(hour: 6, minute: 30),
            eventTriggers: [], mutable: true
        )
        let lateEvening = makeDate(year: 2026, month: 5, day: 1, hour: 23, minute: 0)
        let earlyMorning = makeDate(year: 2026, month: 5, day: 2, hour: 5, minute: 0)
        let midDay = makeDate(year: 2026, month: 5, day: 1, hour: 12, minute: 0)
        XCTAssertTrue(schedule.isQuietHours(at: lateEvening))
        XCTAssertTrue(schedule.isQuietHours(at: earlyMorning))
        XCTAssertFalse(schedule.isQuietHours(at: midDay))
    }

    func test_parse_missingBPM_defaultsTo30() async throws {
        let raw = """
            ---
            quiet_hours: ["22:00", "06:30"]
            mutable: true
            ---
            # schedule

            body

            """
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("schedule-\(UUID().uuidString).md")
        try Data(raw.utf8).write(to: temp, options: .atomic)
        addTeardownBlock { try? FileManager.default.removeItem(at: temp) }

        let store = BotStore()
        let file = try await store.read(temp)
        let schedule = try HeartbeatSchedule.parse(file)
        XCTAssertEqual(schedule.bpm, 30, "missing bpm should default to 30")
    }

    // MARK: - Helpers

    private func loadCanonicalBot() async throws -> Bot {
        let fixturesURL = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/canonical-bot")
        let store = BotStore()
        return try await store.load(at: fixturesURL)
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
