import SpriteKit
import SwiftUI

/// The root SKScene for the anatomy area (top half of HomeView).
///
/// Slice 2 ships face composition only. Slices 3+ add organs, heart, wiring, and
/// touch-handling for organ taps.
public final class AnatomyScene: SKScene {
    public private(set) var face: FaceComposite?

    public override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFit
        backgroundColor = SKColor(red: 0.09, green: 0.08, blue: 0.06, alpha: 1.0)  // warm dark
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Installs Hilfer (the static Phase 4 face). Replace with a configurable Model loader
    /// in Slice 9 when `manufacturers.json` is wired up.
    public func installHilferFace() {
        let skull = SkullNode(textureName: "HilferSkull", anchorPoints: .hilferDefaults)
        let eyes = EyesNode(textureName: "HilferEyes")
        let jaw = JawNode(textureName: "HilferJaw")
        let decals = DecalNode()
        let composite = FaceComposite(skull: skull, eyes: eyes, jaw: jaw, decals: decals)
        composite.node.position = .zero
        addChild(composite.node)
        self.face = composite
    }
}
