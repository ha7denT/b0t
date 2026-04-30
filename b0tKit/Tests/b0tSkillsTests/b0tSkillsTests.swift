import XCTest

@testable import b0tSkills

final class b0tSkillsTests: XCTestCase {
    func test_modulePlaceholder_identifierMatchesModuleName() {
        XCTAssertEqual(b0tSkillsPlaceholder.identifier, "b0tSkills")
    }
}
