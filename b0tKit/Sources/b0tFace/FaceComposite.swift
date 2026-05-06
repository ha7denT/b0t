import SpriteKit

/// Composes the three Parts + decal layer into a single SKNode subtree.
///
/// Z-order (bottom to top):
/// 1. Eyes — eye-screen content visible through the Skull's cutout.
/// 2. Skull — polymer shell with eye-cutout window.
/// 3. Jaw — mounted at Skull's `jawHinge` anchor.
/// 4. Decals — additive markings on top of all Parts.
///
/// Phase 4 is static; Phase 6 adds rig animation by mutating Part textures
/// (mood-state machine) without changing this composition.
public final class FaceComposite {
    public let node: SKNode
    public let skull: SkullNode
    public let eyes: EyesNode
    public let jaw: JawNode
    public let decals: DecalNode

    public init(skull: SkullNode, eyes: EyesNode, jaw: JawNode, decals: DecalNode) {
        self.skull = skull
        self.eyes = eyes
        self.jaw = jaw
        self.decals = decals

        let root = SKNode()
        root.name = "face_composite"

        // Position children by skull's anchor points, in scene-space relative to
        // a 256x256 face origin at (0,0).
        let faceSize: CGFloat = 256

        eyes.node.position = CGPoint(
            x: (skull.anchorPoints.eyesSocket.x - 0.5) * faceSize,
            y: (skull.anchorPoints.eyesSocket.y - 0.5) * faceSize
        )
        skull.node.position = .zero
        jaw.node.position = CGPoint(
            x: (skull.anchorPoints.jawHinge.x - 0.5) * faceSize,
            y: (skull.anchorPoints.jawHinge.y - 0.5) * faceSize
        )
        decals.node.position = .zero

        root.addChild(eyes.node)
        root.addChild(skull.node)
        root.addChild(jaw.node)
        root.addChild(decals.node)

        self.node = root
    }
}
