import SpriteKit
import SwiftUI

/// The root SKScene for the anatomy area (top half of HomeView).
///
/// Slice 3 ships face + 10-organ columns + heart + wiring. Slice 4 adds touch-handling
/// for organ taps; Slice 8 wires tool-event pulses through the wiring network.
public final class AnatomyScene: SKScene {
    public private(set) var face: FaceComposite?
    public private(set) var heart: HeartNode?
    public private(set) var wiring: WiringNetwork?
    public private(set) var organs: [OrganID: OrganNode] = [:]

    /// Closure invoked when the user taps a named organ in the scene.
    /// `SceneStateBridge` sets this to mutate `AnatomyState.selectedOrgan`.
    public var tapHandler: ((OrganID) -> Void)?

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

    /// Installs Hilfer's face plus the 10-organ columns, heart, and wiring network.
    public func installFullAnatomy(initialBPM: Int) {
        installHilferFace()
        installOrgansAndHeart(initialBPM: initialBPM)
        installWiring()
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
