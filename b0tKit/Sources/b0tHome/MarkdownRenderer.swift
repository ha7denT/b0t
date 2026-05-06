import SwiftUI

import b0tDesign

/// Renders markdown prose in the LCD inspection panel.
/// v1: trust SwiftUI's `Text(.init(markdown:))` for inline emphasis. Block-level
/// elements (lists, headings) render naïvely; the cassette-futurism aesthetic
/// keeps prose terse so this is acceptable for Phase 4.
public struct MarkdownRenderer: View {
    let markdown: String

    public init(markdown: String) {
        self.markdown = markdown
    }

    public var body: some View {
        ScrollView {
            Text(LocalizedStringKey(markdown))
                .font(Typography.chatBody(size: 14))
                .foregroundStyle(LCDPalette.textAmber)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
