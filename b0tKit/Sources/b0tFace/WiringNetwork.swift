import SpriteKit
import SwiftUI
import b0tDesign

public enum WiringDirection {
    case inbound  // organ → face (reads, sensor input)
    case outbound  // face → organ (tool calls, writes)
}

/// Phosphor-glow lines connecting organs to the face. Direction-aware pulses
/// move along the line during tool calls / memory reads / writes.
///
/// Per `aesthetic-references.md`: warm phosphor — amber, green, cream. Never blue.
public final class WiringNetwork {
    public let node: SKNode

    public init() {
        let root = SKNode()
        root.name = "wiring"
        self.node = root
    }

    /// Installs one wiring line per organ (9 organs — heart is distinguished, no wire).
    /// Endpoints derive from `AnatomyLayout.position(for:)`, so they follow the column layout.
    public func installLines(faceCentre: CGPoint, organSize: CGSize) {
        for organ in OrganID.allCases where organ != .heart {
            let target = AnatomyLayout.position(for: organ, in: organSize)
            let line = makeLine(from: faceCentre, to: target)
            line.name = "wire_\(organ.rawValue)"
            node.addChild(line)
        }
    }

    /// Briefly pulse a line's brightness to show data flow.
    public func pulse(_ organ: OrganID, direction: WiringDirection) {
        guard let line = node.childNode(withName: "wire_\(organ.rawValue)") as? SKShapeNode else { return }
        line.removeAction(forKey: "pulse")
        let bright = SKAction.run { [weak line] in line?.alpha = 1.0 }
        let dim = SKAction.fadeAlpha(to: 0.35, duration: 0.6)
        line.run(SKAction.sequence([bright, dim]), withKey: "pulse")
        _ = direction  // direction influences future colour-tween animation; v1 just intensifies
    }

    private func makeLine(from a: CGPoint, to b: CGPoint) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: a)
        path.addLine(to: b)
        let line = SKShapeNode(path: path)
        // Dimmed aqua (#3DEAFF × 0.8) — function/IO semantic colour, pipe-style.
        line.strokeColor = SKColor(
            red: 0x3D / 255.0 * 0.8,
            green: 0xEA / 255.0 * 0.8,
            blue: 0xFF / 255.0 * 0.8,
            alpha: 1
        )
        line.lineWidth = 5
        line.alpha = 0.35  // dim at rest
        line.glowWidth = 2.5
        return line
    }
}
