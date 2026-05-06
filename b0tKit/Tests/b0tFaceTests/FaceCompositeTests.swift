import SpriteKit
import XCTest

@testable import b0tFace

final class FaceCompositeTests: XCTestCase {
    func test_composite_layersAreInCorrectZOrder() {
        let composite = makeHilferComposite()
        // Eye-screen at the back, Skull on top with cutout, Jaw at hinge, Decals on top.
        // Children are listed bottom-to-top: [eyes, skull, jaw, decals]
        let names = composite.node.children.map { $0.name ?? "" }
        XCTAssertEqual(names, ["eyes", "skull", "jaw", "decals"])
    }

    func test_composite_jawIsPositionedAtHingeAnchor() {
        let composite = makeHilferComposite()
        guard let jaw = composite.node.childNode(withName: "jaw") else {
            XCTFail("jaw missing")
            return
        }
        // jawHinge (0.5, 0.25) → centred horizontally, in lower half (y < 0).
        XCTAssertEqual(jaw.position.x, 0, accuracy: 0.5)
        XCTAssertLessThan(jaw.position.y, 0, "jaw should be in lower half")
    }

    func test_composite_eyesIsPositionedAtSocketAnchor() {
        let composite = makeHilferComposite()
        guard let eyes = composite.node.childNode(withName: "eyes") else {
            XCTFail("eyes missing")
            return
        }
        // eyesSocket (0.5, 0.55) — slightly above centre.
        XCTAssertEqual(eyes.position.x, 0, accuracy: 0.5)
        XCTAssertGreaterThan(eyes.position.y, 0, "eyes socket should be above centre")
    }

    private func makeHilferComposite() -> FaceComposite {
        let skull = SkullNode(textureName: "HilferSkull", anchorPoints: .hilferDefaults)
        let eyes = EyesNode(textureName: "HilferEyes")
        let jaw = JawNode(textureName: "HilferJaw")
        let decals = DecalNode()
        return FaceComposite(skull: skull, eyes: eyes, jaw: jaw, decals: decals)
    }
}
