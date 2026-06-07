import SpriteKit
import SwiftUI

/// The root SKScene for the anatomy area (top half of HomeView).
///
/// Slice 3 ships face + 10-organ columns + heart + wiring. Slice 4 adds touch-handling
/// for organ taps; Slice 8 wires tool-event pulses through the wiring network.
public final class AnatomyScene: SKScene {
    // MARK: — Hilfer path (tests + previews; kept intact)
    public private(set) var face: FaceComposite?

    // MARK: — WunderHead path (production)
    /// The single-unit head sprite (WunderHead). Non-nil after `installWunderFace()`.
    public private(set) var headNode: SKSpriteNode?
    /// Token-yellow emissive grille shape behind the head. Non-nil after `installWunderFace()`.
    public private(set) var grille: SKShapeNode?

    public private(set) var heart: HeartNode?
    public private(set) var wiring: WiringNetwork?
    public private(set) var organs: [OrganID: OrganNode] = [:]

    /// Closure invoked when the user taps a named organ in the scene.
    /// `SceneStateBridge` sets this to mutate `AnatomyState.selectedOrgan`.
    public var tapHandler: ((OrganID) -> Void)?

    public override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFit
        // Cool dark teal base (ADR-0016 — warm amber replaced by aqua-derived dark).
        backgroundColor = SKColor(red: 0.045, green: 0.075, blue: 0.075, alpha: 1.0)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Installs WunderHead (single-unit) face plus the 10-organ columns, heart, and wiring network.
    /// Production entry point.
    public func installFullAnatomy(initialBPM: Int) {
        installWunderFace()
        installOrgansAndHeart(initialBPM: initialBPM)
        installWiring()
    }

    /// Installs the single-unit WunderHead face with ADR-0014 emissive grille.
    ///
    /// Structure (flat, both as direct scene children):
    /// - `"grille_emissive"` — token-yellow `SKShapeNode`, `zPosition = -1` (behind head)
    /// - `"face_unit"` — `SKSpriteNode(imageNamed: "WunderHead")`, `zPosition = 0`
    public func installWunderFace() {
        guard headNode == nil else { return }

        // Token yellow: #EAFF3D
        let grilleNode = SKShapeNode(
            rectOf: CGSize(width: 38, height: 18),
            cornerRadius: 4
        )
        grilleNode.fillColor = SKColor(
            red: 0xEA / 255.0,
            green: 0xFF / 255.0,
            blue: 0x3D / 255.0,
            alpha: 1.0
        )
        grilleNode.strokeColor = .clear
        grilleNode.glowWidth = 6.0
        grilleNode.alpha = 0.9
        grilleNode.position = CGPoint(x: 0, y: -64)
        grilleNode.zPosition = -1
        grilleNode.name = "grille_emissive"
        addChild(grilleNode)
        self.grille = grilleNode

        let texture = SKTexture(imageNamed: "WunderHead")
        texture.filteringMode = .nearest
        let head = SKSpriteNode(texture: texture, size: CGSize(width: 256, height: 256))
        head.position = .zero
        head.zPosition = 0
        head.name = "face_unit"
        addChild(head)
        self.headNode = head
    }

    /// Installs Hilfer face only (used by AnatomyView previews and slice 2 tests).
    public func installHilferFace() {
        guard face == nil else { return }
        let skull = SkullNode(textureName: "HilferSkull", anchorPoints: .hilferDefaults)
        let eyes = EyesNode(textureName: "HilferEyes")
        let jaw = JawNode(textureName: "HilferJaw")
        let decals = DecalNode()
        let composite = FaceComposite(skull: skull, eyes: eyes, jaw: jaw, decals: decals)
        composite.node.position = .zero
        addChild(composite.node)
        self.face = composite
    }

    private func installOrgansAndHeart(initialBPM: Int) {
        for organ in OrganID.allCases where organ != .heart {
            let node = OrganNode(organ: organ, textureName: textureName(for: organ))
            node.node.position = AnatomyLayout.position(for: organ, in: size)
            addChild(node.node)
            organs[organ] = node
        }
        let heart = HeartNode(textureName: "OrganHeart")
        heart.node.position = AnatomyLayout.position(for: .heart, in: size)
        addChild(heart.node)
        heart.startPulsing(bpm: initialBPM)
        self.heart = heart
    }

    private func installWiring() {
        let wiring = WiringNetwork()
        wiring.installLines(faceCentre: .zero, organSize: size)
        wiring.node.zPosition = -3  // pipes behind everything: grille z=-1, face z=0, organs z=0
        addChild(wiring.node)
        self.wiring = wiring
    }

    #if canImport(UIKit)
        public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            let location = touch.location(in: self)
            let hits = nodes(at: location)
            for node in hits {
                if let name = node.name, let organ = OrganID(rawValue: name) {
                    tapHandler?(organ)
                    return
                }
            }
        }
    #endif

    private func textureName(for organ: OrganID) -> String {
        switch organ {
        case .reasoning: return "OrganReasoning"
        case .memory: return "OrganMemory"
        case .identity: return "OrganIdentity"
        case .modules: return "OrganModules"
        case .sensors: return "OrganSensors"
        case .tools: return "OrganTools"
        case .network: return "OrganNetwork"
        case .location: return "OrganLocation"
        case .journal: return "OrganJournal"
        case .heart: return "OrganHeart"
        }
    }
}
