import SwiftUI

/// Hilfer's palette — the Wundercog tier-1 starter Model.
///
/// Values are sRGB literals; tweak with Jamee's eye against the Hilfer PNGs.
public enum WundercogPalette {
    /// Off-white polymer shell — Hilfer's skull and jaw base.
    public static let shellOffwhite = Color(red: 0.93, green: 0.92, blue: 0.88)

    /// Mint-green accent — eye glow halo, jaw underline, bezel highlight.
    public static let accentMint = Color(red: 0.62, green: 0.86, blue: 0.74)

    /// Single-pixel mint bezel ringing the eye-screen cutout.
    public static let bezelMintThin = Color(red: 0.55, green: 0.78, blue: 0.66)

    /// Phosphor glow inside the eye-screen.
    public static let eyePhosphor = Color(red: 0.45, green: 0.92, blue: 0.62)

    /// Subtle panel-seam shadowing.
    public static let seamDark = Color(red: 0.18, green: 0.18, blue: 0.16)
}
