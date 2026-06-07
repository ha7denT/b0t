import SwiftUI

/// Backlit-LCD inspection panel palette.
///
/// Backlit monochrome over a muted dark base — no bloom, no scanlines.
/// Property names are legacy (warm→cool per ADR-0016); values updated in GUI polish pass.
/// Distinct from the CRT phosphor palette used on the Eye-screen.
public enum LCDPalette {
    /// Dark cool teal base — the LCD background (darkened aqua highlight shade per ADR-0016).
    public static let bgWarm = Color(red: 0.05, green: 0.08, blue: 0.08)

    /// Light cool monochrome text — chat content, organ titles, frontmatter labels.
    public static let textAmber = Color(red: 0.82, green: 0.90, blue: 0.92)

    /// Secondary dimmed text — subtitles, system labels.
    public static let textDim = Color(red: 0.82, green: 0.90, blue: 0.92).opacity(0.55)

    /// Dark chrome border around the LCD area.
    public static let chromeDark = Color(red: 0.03, green: 0.05, blue: 0.05)
}
