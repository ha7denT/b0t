import SpriteKit

/// Anchor points the Skull exposes for positioning Eyes and Jaw, in normalised (0-1) coords.
public struct SkullAnchorPoints: Equatable, Sendable {
    public let eyesSocket: CGPoint
    public let jawHinge: CGPoint

    public init(eyesSocket: CGPoint, jawHinge: CGPoint) {
        self.eyesSocket = eyesSocket
        self.jawHinge = jawHinge
    }

    /// Hilfer's anchor defaults — settled per the spec / `face-roster.md`.
    public static let hilferDefaults = SkullAnchorPoints(
        eyesSocket: CGPoint(x: 0.5, y: 0.55),
        jawHinge: CGPoint(x: 0.5, y: 0.25)
    )
}

/// The skull Part — outer polymer shell with the eye-cutout window.
public final class SkullNode: FacePart {
    public let kind: FacePartKind = .skull
    public let node: SKNode
    public let anchorPoints: SkullAnchorPoints

    public init(textureName: String, anchorPoints: SkullAnchorPoints) {
        self.anchorPoints = anchorPoints
        let texture = SKTexture(imageNamed: textureName)
        texture.filteringMode = .nearest
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: 256, height: 256))
        sprite.name = "skull"
        self.node = sprite
    }
}
