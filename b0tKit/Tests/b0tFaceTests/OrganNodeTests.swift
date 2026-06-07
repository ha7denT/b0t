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

    func test_organNode_appliesSemanticTint() {
        // Mask-tint: colorBlendFactor must be fully on so the silhouette renders in the
        // semantic colour (ADR-0016 / spec §4).
        let organ = OrganNode(organ: .memory, textureName: "OrganMemory")
        guard let sprite = organ.node as? SKSpriteNode else { return XCTFail() }
        XCTAssertEqual(sprite.colorBlendFactor, 1.0, accuracy: 0.001)
    }

    func test_organNode_processorIsYellow_organsAreAqua() {
        guard
            let processor = OrganNode(organ: .reasoning, textureName: "OrganReasoning").node
                as? SKSpriteNode,
            let aqua = OrganNode(organ: .network, textureName: "OrganNetwork").node as? SKSpriteNode
        else { return XCTFail() }
        var pr: CGFloat = 0
        var pg: CGFloat = 0
        var pb: CGFloat = 0
        var pa: CGFloat = 0
        processor.color.getRed(&pr, green: &pg, blue: &pb, alpha: &pa)
        // yellow #EAFF3D — red high, blue low
        XCTAssertGreaterThan(pr, pb)

        var ar: CGFloat = 0
        var ag: CGFloat = 0
        var ab: CGFloat = 0
        var aa: CGFloat = 0
        aqua.color.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        // aqua #3DEAFF — blue high, red low
        XCTAssertGreaterThan(ab, ar)
    }
}

extension OrganID {
    // Verbatim leftover from an earlier draft of the spec where calendar was a separate organ
    // before being subsumed into Tools. Returns `.tools`. Kept to preserve the original test
    // shape from the slice 3 plan; renamed lowerCamelCase to satisfy swift-format.
    fileprivate static func calendarAliasedToTools() -> OrganID { .tools }
}
