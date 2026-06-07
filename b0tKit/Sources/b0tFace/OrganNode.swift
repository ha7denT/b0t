import SpriteKit

/// A single organ in the ring — 64px sprite + activity-pulse action.
///
/// Activity-pulse is procedural (no separate "active" PNG) — `SKAction.colorize`
/// + scale tween over the idle sprite. Triggered when the organ is being read /
/// written (memory, modules, tools) or when its corresponding tool is invoked.
public final class OrganNode {
    public let organ: OrganID
    public let node: SKNode

    public init(organ: OrganID, textureName: String) {
        self.organ = organ
        let texture = SKTexture(imageNamed: textureName)
        texture.filteringMode = .nearest
        let size = (organ == .heart) ? AnatomyLayout.heartSize : AnatomyLayout.organSize
        let sprite = SKSpriteNode(texture: texture, size: size)
        sprite.name = organ.rawValue
        // Semantic tint (ADR-0016 / spec §4): mask-tint the transparent silhouette.
        // Processor (reasoning) = yellow; all other organs = aqua.
        sprite.color = OrganNode.tint(for: organ)
        sprite.colorBlendFactor = 1.0
        self.node = sprite
    }

    /// Semantic backlight colour for an organ silhouette (ADR-0016, spec §4).
    private static func tint(for organ: OrganID) -> SKColor {
        switch organ {
        case .reasoning:
            // processor — yellow #EAFF3D
            return SKColor(red: 0xEA / 255.0, green: 0xFF / 255.0, blue: 0x3D / 255.0, alpha: 1.0)
        default:
            // organs — aqua #3DEAFF
            return SKColor(red: 0x3D / 255.0, green: 0xFF / 255.0, blue: 0xEA / 255.0, alpha: 1.0)
        }
    }

    /// One-shot activity pulse — the organ "lights up" for ~600ms.
    public func activityPulseAction() -> SKAction {
        let scaleUp = SKAction.scale(to: 1.12, duration: 0.18)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.42)
        scaleUp.timingMode = .easeOut
        scaleDown.timingMode = .easeIn
        return SKAction.sequence([scaleUp, scaleDown])
    }
}
