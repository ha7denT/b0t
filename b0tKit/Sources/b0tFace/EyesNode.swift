import SpriteKit
import b0tDesign

/// The eye-screen Part — the only CRT surface in the system.
///
/// Wrapped in `SKEffectNode` so the scanline shader applies. The underlying SKSpriteNode
/// is the eye-content texture (mint phosphor for Hilfer); the shader overlays subtle
/// scanlines.
///
/// The Eye-screen mounts behind the Skull's eye-cutout in `FaceComposite` z-order.
public final class EyesNode: FacePart {
    public let kind: FacePartKind = .eyes
    public let node: SKNode

    public init(textureName: String) {
        let effect = SKEffectNode()
        effect.shouldEnableEffects = true
        effect.shouldRasterize = true
        effect.shader = CRTScanlineShader.make()
        effect.name = "eyes"

        let texture = SKTexture(imageNamed: textureName)
        texture.filteringMode = .nearest
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: 256, height: 256))
        sprite.name = "eyes_sprite"
        effect.addChild(sprite)

        self.node = effect
    }
}
