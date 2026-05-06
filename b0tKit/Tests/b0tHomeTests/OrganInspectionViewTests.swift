import SwiftUI
import XCTest

import b0tBrain
import b0tFace

@testable import b0tHome

@MainActor
final class OrganInspectionViewTests: XCTestCase {
    func test_inspectingHeart_rendersWithFrontmatterControls() throws {
        let state = makeState()
        state.selectedOrgan = .heart
        let view = OrganInspectionView(state: state, organ: .heart, file: try heartFixture())
        // Smoke: view body constructs without trapping.
        _ = view.body
    }

    func test_committingBPM_updatesAnatomyStateHeartBPM() throws {
        // The commit() handler must update state.heartBPM for keys
        // "heartbeat_bpm" / "bpm" so HomeView's onChange restarts the heart pulse.
        let state = makeState()
        let view = OrganInspectionView(state: state, organ: .heart, file: try heartFixture())
        view.commit(key: "heartbeat_bpm", value: .int(8))
        XCTAssertEqual(state.heartBPM, 8)
    }

    func test_committingNonBPMKey_doesNotChangeHeartBPM() throws {
        // Non-BPM keys must not touch state.heartBPM (regression-guard).
        let state = makeState()
        let view = OrganInspectionView(state: state, organ: .heart, file: try heartFixture())
        view.commit(key: "quiet_hours", value: .array([.string("22:00"), .string("06:30")]))
        XCTAssertEqual(state.heartBPM, 4)  // unchanged from initial
    }

    private func makeState() -> AnatomyState {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        return AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
    }

    private func heartFixture() throws -> BotFile {
        // Real BotFile parsed from in-memory text — no disk required.
        let url = URL(fileURLWithPath: "/tmp/test-bot/heartbeat/schedule.md")
        let text = """
            ---
            heartbeat_bpm: 4
            ---

            # schedule

            body.
            """
        return try BotFile(fileURL: url, text: text)
    }
}
