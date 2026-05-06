import SpriteKit
import XCTest

@testable import b0tFace

final class JawNodeTests: XCTestCase {
    func test_jawNode_kindIsJaw() {
        let jaw = JawNode(textureName: "HilferJaw")
        XCTAssertEqual(jaw.kind, .jaw)
    }

    func test_jawNode_rendersAt256pxNative() {
        let jaw = JawNode(textureName: "HilferJaw")
        guard let sprite = jaw.node as? SKSpriteNode else {
            XCTFail("expected SKSpriteNode for jaw root")
            return
        }
        XCTAssertEqual(sprite.size.width, 256)
        XCTAssertEqual(sprite.size.height, 256)
    }

    func test_jawNode_isNamed() {
        let jaw = JawNode(textureName: "HilferJaw")
        XCTAssertEqual(jaw.node.name, "jaw")
    }
}
