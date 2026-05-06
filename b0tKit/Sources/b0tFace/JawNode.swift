import SpriteKit

/// The jaw Part — mounts to the Skull's `jawHinge` anchor point.
///
/// The Skull occludes the jaw's sides; the speaker lives behind the jaw plane
/// (no speaker grille on the jaw itself).
public final class JawNode: FacePart {
    public let kind: FacePartKind = .jaw
    public let node: SKNode

    public init(textureName: String) {
        let texture = SKTexture(imageNamed: textureName)
        texture.filteringMode = .nearest
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: 256, height: 256))
        sprite.name = "jaw"
        self.node = sprite
    }
}
