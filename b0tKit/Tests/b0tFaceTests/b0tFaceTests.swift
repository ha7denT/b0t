import XCTest

@testable import b0tFace

final class b0tFaceTests: XCTestCase {
    func test_modulePlaceholder_identifierMatchesModuleName() {
        XCTAssertEqual(b0tFacePlaceholder.identifier, "b0tFace")
    }
}
