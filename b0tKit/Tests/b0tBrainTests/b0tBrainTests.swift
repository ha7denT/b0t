import XCTest
@testable import b0tBrain

final class b0tBrainTests: XCTestCase {
    func test_modulePlaceholder_identifierMatchesModuleName() {
        XCTAssertEqual(b0tBrainPlaceholder.identifier, "b0tBrain")
    }
}
