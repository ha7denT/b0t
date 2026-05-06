import SpriteKit
import XCTest

@testable import b0tFace

@MainActor
final class WiringNetworkTests: XCTestCase {
    func test_wiring_hasOneLinePerOrgan() {
        let wiring = WiringNetwork()
        wiring.installLines(faceCentre: .zero, organSize: CGSize(width: 390, height: 480))
        // 8 ring organs (heart is distinguished — its line is implicit / different style)
        let lines = wiring.node.children.compactMap { $0 as? SKShapeNode }
        XCTAssertEqual(lines.count, 8)
    }

    func test_wiring_pulseInbound_runsActionOnLine() {
        let wiring = WiringNetwork()
        wiring.installLines(faceCentre: .zero, organSize: CGSize(width: 390, height: 480))
        wiring.pulse(.memory, direction: .inbound)
        let line = wiring.node.childNode(withName: "wire_memory")
        XCTAssertNotNil(line?.action(forKey: "pulse"))
    }

    func test_wiring_pulseOutbound_runsActionOnLine() {
        let wiring = WiringNetwork()
        wiring.installLines(faceCentre: .zero, organSize: CGSize(width: 390, height: 480))
        wiring.pulse(.tools, direction: .outbound)
        let line = wiring.node.childNode(withName: "wire_tools")
        XCTAssertNotNil(line?.action(forKey: "pulse"))
    }
}
