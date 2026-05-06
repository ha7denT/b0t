import SpriteKit

/// Decal layer — manufacturer marks, hazard stripes, stencils.
///
/// Architecturally present in Phase 4; empty for Hilfer (clean polymer aesthetic).
/// Decals are additive `SKSpriteNode`s composed on top of Parts. Each decal is itself
/// a baked PNG from the asset pipeline (per amendment §2.2 — no runtime tinting).
public final class DecalNode {
    public let node: SKNode

    public init() {
        let container = SKNode()
        container.name = "decals"
        self.node = container
    }

    public func add(_ decal: SKNode) {
        node.addChild(decal)
    }
}
