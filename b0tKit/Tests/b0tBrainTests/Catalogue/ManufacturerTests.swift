import XCTest

@testable import b0tBrain

final class ManufacturerTests: XCTestCase {
    func test_decodes_fromJSON() throws {
        let json = """
            {
              "id": "wundercog",
              "name": "Wundercog Industries",
              "base_prompt_template": "...",
              "palettes": ["wundercog_offwhite_mint"],
              "identity_description": "Friendly utility aesthetic"
            }
            """
        let m = try JSONDecoder().decode(Manufacturer.self, from: Data(json.utf8))
        XCTAssertEqual(m.id, "wundercog")
        XCTAssertEqual(m.name, "Wundercog Industries")
        XCTAssertEqual(m.palettes, ["wundercog_offwhite_mint"])
        XCTAssertEqual(m.identityDescription, "Friendly utility aesthetic")
    }
}
