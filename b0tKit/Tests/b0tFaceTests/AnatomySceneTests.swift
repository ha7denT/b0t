import SpriteKit
import XCTest

@testable import b0tFace

final class AnatomySceneTests: XCTestCase {
    func test_anatomyScene_initialState_hasFaceComposite() {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        scene.installHilferFace()
        XCTAssertNotNil(scene.childNode(withName: "face_composite"))
    }

    func test_anatomyScene_scaleMode_isAspectFit() {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        XCTAssertEqual(scene.scaleMode, .aspectFit)
    }

    func test_anatomyScene_backgroundColor_isWarmDark() {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        XCTAssertNotEqual(scene.backgroundColor, .black)
    }
}
