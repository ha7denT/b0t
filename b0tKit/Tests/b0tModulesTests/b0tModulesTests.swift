import XCTest

@testable import b0tModules

final class b0tModulesTests: XCTestCase {
    func test_modulePlaceholder_identifierMatchesModuleName() {
        XCTAssertEqual(b0tModulesPlaceholder.identifier, "b0tModules")
    }
}
