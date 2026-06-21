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

    // MARK: — WunderHead / ADR-0014 tests

    func test_installFullAnatomy_hasFaceUnit() {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        scene.installFullAnatomy(initialBPM: 4)
        XCTAssertNotNil(
            scene.childNode(withName: "face_unit"), "face_unit node must exist after installFullAnatomy")
    }

    func test_installFullAnatomy_hasGrilleEmissive() {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        scene.installFullAnatomy(initialBPM: 4)
        XCTAssertNotNil(
            scene.childNode(withName: "grille_emissive"),
            "grille_emissive node must exist after installFullAnatomy")
    }

    func test_installWunderFace_isIdempotent() {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        scene.installWunderFace()
        scene.installWunderFace()
        let faceUnitNodes = scene.children.filter { $0.name == "face_unit" }
        XCTAssertEqual(
            faceUnitNodes.count, 1, "installWunderFace must be idempotent — exactly one face_unit node")
    }

    func test_installWunderFace_headNodeAndGrilleRefsSet() {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        scene.installWunderFace()
        XCTAssertNotNil(scene.headNode)
        XCTAssertNotNil(scene.grille)
    }

    func test_installWunderFace_grilleIsBehindHead() {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        scene.installWunderFace()
        XCTAssertEqual(scene.grille?.zPosition ?? 0, -1)
        XCTAssertEqual(scene.headNode?.zPosition ?? -999, 0)
    }

    func test_faceTapHandler_isInvokable() {
        let scene = AnatomyScene(size: CGSize(width: 256, height: 256))
        scene.installWunderFace()
        var tapped = false
        scene.faceTapHandler = { tapped = true }
        scene.faceTapHandler?()
        XCTAssertTrue(tapped)
    }

    func test_installWunderFace_namesFaceUnit() {
        let scene = AnatomyScene(size: CGSize(width: 256, height: 256))
        scene.installWunderFace()
        XCTAssertEqual(scene.headNode?.name, "face_unit")
    }
}
