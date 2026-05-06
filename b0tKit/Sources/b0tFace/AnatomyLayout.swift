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
    /// Asymmetric upper ring per spec §3 decision 4.
    public static func position(for organ: OrganID, in size: CGSize) -> CGPoint {
        let r: CGFloat = 180  // ring radius
        switch organ {
        // ABOVE EYE-LINE (4 organs, asymmetric)
        case .reasoning: return CGPoint(x: 0, y: r)  // 12 o'clock — crown
        case .modules: return CGPoint(x: -r * 0.78, y: r * 0.55)  // 10–11 o'clock
        case .memory: return CGPoint(x: r * 0.78, y: r * 0.55)  // 1–2 o'clock
        case .identity: return CGPoint(x: -r, y: 0)  // 9 o'clock (left ear)

        // BELOW EYE-LINE (4 organs)
        case .tools: return CGPoint(x: -r * 0.78, y: -r * 0.55)  // 7–8 o'clock
        case .sensors: return CGPoint(x: r * 0.78, y: -r * 0.55)  // 4–5 o'clock
        case .location: return CGPoint(x: -r * 0.42, y: -r * 0.92)  // 7 o'clock-ish, deeper
        case .network: return CGPoint(x: r * 0.42, y: -r * 0.92)  // 5 o'clock-ish, deeper

        // BOTTOM-CENTRE (distinguished)
        case .heart: return CGPoint(x: 0, y: -r * 1.18)  // below the lower ring
        }
    }
}
