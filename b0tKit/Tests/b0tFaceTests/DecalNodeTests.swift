import SpriteKit
import XCTest

@testable import b0tFace

final class DecalNodeTests: XCTestCase {
    func test_decalNode_isInitiallyEmpty() {
        let decals = DecalNode()
        XCTAssertTrue(decals.node.children.isEmpty)
    }

    func test_decalNode_acceptsAddedDecals() {
        let decals = DecalNode()
        let decal = SKSpriteNode(color: .red, size: CGSize(width: 16, height: 16))
        decals.add(decal)
        XCTAssertEqual(decals.node.children.count, 1)
    }

    func test_decalNode_isNamed() {
        XCTAssertEqual(DecalNode().node.name, "decals")
    }
}
