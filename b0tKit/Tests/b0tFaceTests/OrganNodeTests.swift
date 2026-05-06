import SpriteKit
import XCTest

@testable import b0tFace

final class OrganNodeTests: XCTestCase {
    func test_organNode_isNamedByOrganID() {
        let node = OrganNode(organ: .calendarAliasedToTools(), textureName: "OrganTools")
        XCTAssertEqual(node.node.name, "tools")
    }

    func test_organNode_idleSize_is64() {
        let node = OrganNode(organ: .memory, textureName: "OrganMemory")
        guard let sprite = node.node as? SKSpriteNode else {
            XCTFail()
            return
        }
        XCTAssertEqual(sprite.size.width, 64)
        XCTAssertEqual(sprite.size.height, 64)
    }

    func test_organNode_pulseAction_isAvailable() {
        let node = OrganNode(organ: .memory, textureName: "OrganMemory")
        let action = node.activityPulseAction()
        XCTAssertNotNil(action)
        XCTAssertGreaterThan(action.duration, 0)
    }
}

extension OrganID {
    // Verbatim leftover from an earlier draft of the spec where calendar was a separate organ
    // before being subsumed into Tools. Returns `.tools`. Kept to preserve the original test
    // shape from the slice 3 plan; renamed lowerCamelCase to satisfy swift-format.
    fileprivate static func calendarAliasedToTools() -> OrganID { .tools }
}
