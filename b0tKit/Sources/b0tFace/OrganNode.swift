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
        self.node = sprite
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
