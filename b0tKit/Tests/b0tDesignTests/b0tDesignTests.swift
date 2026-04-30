import XCTest
@testable import b0tDesign

final class b0tDesignTests: XCTestCase {
    func test_modulePlaceholder_identifierMatchesModuleName() {
        XCTAssertEqual(b0tDesignPlaceholder.identifier, "b0tDesign")
    }
}
