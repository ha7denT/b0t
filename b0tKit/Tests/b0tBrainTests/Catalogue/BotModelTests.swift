import XCTest

@testable import b0tBrain

final class BotModelTests: XCTestCase {
    func test_decodes_hilfer() throws {
        let json = """
            {
              "id": "hilfer",
              "manufacturer": "wundercog",
              "tier": 1,
              "is_starter": true,
              "parts": {
                "skull": "wundercog_skull_egg_offwhite_mint",
                "eyes": "wundercog_eyes_mint_idle",
                "jaw": "wundercog_jaw_small_offwhite_mint"
              },
              "palette": "wundercog_offwhite_mint",
              "decals": [],
              "default_personality_dir": "identity/",
              "default_modules": ["calendar"],
              "default_tools": ["calendar.upcoming_events"],
              "heartbeat_unlock_threshold": null
            }
            """
        let model = try JSONDecoder().decode(BotModel.self, from: Data(json.utf8))
        XCTAssertEqual(model.id, "hilfer")
        XCTAssertEqual(model.manufacturer, "wundercog")
        XCTAssertEqual(model.tier, 1)
        XCTAssertTrue(model.isStarter)
        XCTAssertEqual(model.parts.skull, "wundercog_skull_egg_offwhite_mint")
        XCTAssertEqual(model.parts.eyes, "wundercog_eyes_mint_idle")
        XCTAssertEqual(model.parts.jaw, "wundercog_jaw_small_offwhite_mint")
        XCTAssertEqual(model.palette, "wundercog_offwhite_mint")
        XCTAssertTrue(model.decals.isEmpty)
        XCTAssertEqual(model.defaultPersonalityDir, "identity/")
        XCTAssertEqual(model.defaultModules, ["calendar"])
        XCTAssertEqual(model.defaultTools, ["calendar.upcoming_events"])
        XCTAssertNil(model.heartbeatUnlockThreshold)
    }
}
