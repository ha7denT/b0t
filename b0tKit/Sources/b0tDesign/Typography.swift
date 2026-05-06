import SwiftUI

/// Type system per spec §6.1.
///
/// - `systemMono` — IoskeleyMono NL for system / brain / monospace UI labels.
///   Pixel-grid coherent with the cassette-futurism aesthetic.
/// - `chatBody` — Verdana for chat content inside the LCD chrome.
///   System-provided on iOS, no licensing concern, humanist sans designed for screen
///   readability. Sits inside the LCD without fighting the surrounding pixel art.
public enum Typography {
    public static let systemMonoFamily = "IoskeleyMonoNL-Regular"
    public static let chatBodyFamily = "Verdana"

    public static func systemMono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(systemMonoFamily, size: size).weight(weight)
    }

    public static func chatBody(size: CGFloat) -> Font {
        Font.custom(chatBodyFamily, size: size)
    }
}
