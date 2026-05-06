import SpriteKit

/// The three Parts a face is composed of, per amendment §2.1.
/// Ears are not in scope. Decals are a separate render layer, not a Part.
public enum FacePartKind: String, CaseIterable, Sendable {
    case skull
    case eyes
    case jaw
}

/// A face Part — Skull, Eyes, or Jaw. Each Part renders as one or more SKNode
/// subtrees in the scene, positioned relative to anchors on the Skull.
///
/// Phase 4 ships static (single-frame) Parts. Phase 6 introduces atlas-driven
/// mood-state machines on this protocol via additive extension.
public protocol FacePart: AnyObject {
    /// Which Part this is (Skull / Eyes / Jaw).
    var kind: FacePartKind { get }

    /// The root SKNode for this Part — added as a child of `FaceComposite`.
    var node: SKNode { get }
}
