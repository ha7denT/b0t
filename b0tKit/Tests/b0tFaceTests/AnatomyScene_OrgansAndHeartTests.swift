import SpriteKit
import XCTest

@testable import b0tFace

@MainActor
final class AnatomyScene_OrgansAndHeartTests: XCTestCase {
    func test_installFullAnatomy_addsAll10Organs() {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        scene.installFullAnatomy(initialBPM: 4)
        for organ in OrganID.allCases {
            XCTAssertNotNil(
                scene.childNode(withName: organ.rawValue),
                "organ \(organ) missing from scene"
            )
        }
    }

    func test_installFullAnatomy_addsWiringNetwork() {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        scene.installFullAnatomy(initialBPM: 4)
        XCTAssertNotNil(scene.childNode(withName: "wiring"))
    }

    func test_installFullAnatomy_heartStartsPulsing() {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        scene.installFullAnatomy(initialBPM: 4)
        let heart = scene.childNode(withName: "heart")
        XCTAssertNotNil(heart?.action(forKey: "heartbeat"))
    }
}
