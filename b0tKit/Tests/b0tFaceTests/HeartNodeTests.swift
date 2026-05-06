import SpriteKit
import XCTest

@testable import b0tFace

@MainActor
final class HeartNodeTests: XCTestCase {
    func test_heart_pulsesAtConfiguredBPM() {
        let heart = HeartNode(textureName: "OrganHeart")
        heart.startPulsing(bpm: 4)
        XCTAssertNotNil(heart.node.action(forKey: "heartbeat"))
    }

    func test_heart_changingBPM_restartsPulse() {
        let heart = HeartNode(textureName: "OrganHeart")
        heart.startPulsing(bpm: 4)
        let firstAction = heart.node.action(forKey: "heartbeat")
        heart.startPulsing(bpm: 8)  // different BPM
        let secondAction = heart.node.action(forKey: "heartbeat")
        XCTAssertNotIdentical(firstAction, secondAction)
    }

    func test_heart_pause_stopsPulse() {
        let heart = HeartNode(textureName: "OrganHeart")
        heart.startPulsing(bpm: 4)
        heart.pause()
        XCTAssertNil(heart.node.action(forKey: "heartbeat"))
    }

    func test_heart_isLargerThanRingOrgans() {
        let heart = HeartNode(textureName: "OrganHeart")
        guard let sprite = heart.node as? SKSpriteNode else {
            XCTFail()
            return
        }
        // Heart is distinguished — larger than the 64px ring organs.
        XCTAssertGreaterThan(sprite.size.width, AnatomyLayout.organSize.width)
    }
}
