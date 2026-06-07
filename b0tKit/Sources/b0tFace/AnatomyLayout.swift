import CoreGraphics

/// Locked layout for the anatomy area, per spec §3 decision 4.
///
/// Coordinates are scene-space, with origin at the centre of the anatomy area.
/// Resolutions are normative per amendment §2.3: face 256, organs 64.
public enum AnatomyLayout {
    public static let faceSize = CGSize(width: 256, height: 256)
    public static let organSize = CGSize(width: 64, height: 64)
    public static let heartSize = CGSize(width: 96, height: 96)  // distinguished — slightly larger

    /// Returns the centre position of the given organ in scene-space (origin = centre of anatomy).
    /// Two vertical columns per ADR-0017: processor crown on top, heart at bottom centre,
    /// left column = world-facing I/O (top→bottom), right column = inward / mind (top→bottom).
    /// Scene is 390×540, origin centre, y-up. Columns at ±170 (widened from ±150 in GUI pass).
    public static func position(for organ: OrganID, in size: CGSize) -> CGPoint {
        switch organ {
        case .reasoning: return CGPoint(x: 0, y: 215)  // processor crown
        // left column — world-facing I/O (top→bottom)
        case .network: return CGPoint(x: -170, y: 130)
        case .location: return CGPoint(x: -170, y: 44)
        case .sensors: return CGPoint(x: -170, y: -44)
        case .tools: return CGPoint(x: -170, y: -130)
        // right column — inward / mind (top→bottom)
        case .memory: return CGPoint(x: 170, y: 130)
        case .identity: return CGPoint(x: 170, y: 44)
        case .modules: return CGPoint(x: 170, y: -44)
        case .journal: return CGPoint(x: 170, y: -130)
        case .heart: return CGPoint(x: 0, y: -205)
        }
    }
}
