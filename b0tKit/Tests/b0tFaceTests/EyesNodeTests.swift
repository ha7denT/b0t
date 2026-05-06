import SpriteKit
import XCTest

@testable import b0tDesign
@testable import b0tFace

final class EyesNodeTests: XCTestCase {
    func test_eyesNode_kindIsEyes() {
        let eyes = EyesNode(textureName: "HilferEyes")
        XCTAssertEqual(eyes.kind, .eyes)
    }

    func test_eyesNode_isWrappedInEffectNodeWithShader() {
        let eyes = EyesNode(textureName: "HilferEyes")
        guard let effect = eyes.node as? SKEffectNode else {
            XCTFail("eyes root must be SKEffectNode for shader application")
            return
        }
        XCTAssertNotNil(effect.shader)
        XCTAssertTrue(effect.shouldEnableEffects)
    }

    func test_eyesNode_isOnlyCRTSurface() {
        // smoke: the shader applied is the CRT scanline shader.
        let eyes = EyesNode(textureName: "HilferEyes")
        let effect = eyes.node as? SKEffectNode
        let source = effect?.shader?.source ?? ""
        XCTAssertTrue(source.contains("scanline"), "expected scanline shader, got: \(source.prefix(120))")
    }
}
