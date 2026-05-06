import SwiftUI

/// Backlit-LCD inspection panel palette.
///
/// Calculator / OP-1 / Tandy Model 100 sensibility — warm amber, no bloom, no scanlines.
/// Distinct from the CRT phosphor palette used on the Eye-screen.
public enum LCDPalette {
    /// Warm dark grey-amber backlight — the LCD background.
    public static let bgWarm = Color(red: 0.18, green: 0.14, blue: 0.08)

    /// Primary amber text — chat content, organ titles, frontmatter labels.
    public static let textAmber = Color(red: 0.85, green: 0.72, blue: 0.47)

    /// Secondary dimmed text — subtitles, system labels.
    public static let textDim = Color(red: 0.85, green: 0.72, blue: 0.47).opacity(0.55)

    /// Dark chrome border around the LCD area.
    public static let chromeDark = Color(red: 0.08, green: 0.06, blue: 0.04)
}
