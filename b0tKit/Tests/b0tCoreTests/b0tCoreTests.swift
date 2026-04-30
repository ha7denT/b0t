import XCTest

@testable import b0tCore

final class b0tCoreTests: XCTestCase {
    func test_modulePlaceholder_identifierMatchesModuleName() {
        XCTAssertEqual(b0tCorePlaceholder.identifier, "b0tCore")
    }
}
