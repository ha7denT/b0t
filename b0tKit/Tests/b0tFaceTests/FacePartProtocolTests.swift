import SpriteKit
import XCTest

@testable import b0tFace

final class FacePartProtocolTests: XCTestCase {
    func test_facePart_hasPartKind() {
        XCTAssertEqual(FacePartKind.allCases.count, 3)
        XCTAssertTrue(FacePartKind.allCases.contains(.skull))
        XCTAssertTrue(FacePartKind.allCases.contains(.eyes))
        XCTAssertTrue(FacePartKind.allCases.contains(.jaw))
    }
}
