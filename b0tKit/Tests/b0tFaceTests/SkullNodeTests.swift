import SpriteKit
import XCTest

@testable import b0tFace

final class SkullNodeTests: XCTestCase {
    func test_skullNode_kindIsSkull() {
        let skull = SkullNode(textureName: "HilferSkull", anchorPoints: .hilferDefaults)
        XCTAssertEqual(skull.kind, .skull)
    }

    func test_skullNode_exposesEyesAndJawAnchorPoints() {
        let skull = SkullNode(textureName: "HilferSkull", anchorPoints: .hilferDefaults)
        // The Skull is the source of truth for where Eyes and Jaw go.
        XCTAssertEqual(skull.anchorPoints.eyesSocket, CGPoint(x: 0.5, y: 0.55))
        XCTAssertEqual(skull.anchorPoints.jawHinge, CGPoint(x: 0.5, y: 0.25))
    }

    func test_skullNode_rendersAt256pxNative() {
        let skull = SkullNode(textureName: "HilferSkull", anchorPoints: .hilferDefaults)
        if let sprite = skull.node as? SKSpriteNode {
            // Phase 4 face is 256px native; nearest-neighbour scaling applies later in scene.
            XCTAssertEqual(sprite.size.width, 256)
            XCTAssertEqual(sprite.size.height, 256)
        } else {
            XCTFail("expected SKSpriteNode for skull root")
        }
    }
}
