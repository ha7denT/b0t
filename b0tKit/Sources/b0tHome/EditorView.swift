import SwiftUI

import b0tBrain
import b0tDesign

/// Full-screen markdown editor. Reachable from any non-synthetic OrganInspectionView
/// via an "edit" affordance.
///
/// v1 ships a plain `TextEditor` over the raw `.md` contents (frontmatter inclusive).
/// Save → parse + `BotStore.write`; cancel → discard.
public struct EditorView: View {
    @State private var rawContent: String
    let file: BotFile
    let store: BotStore
    let onClose: () -> Void

    public init(file: BotFile, store: BotStore, onClose: @escaping () -> Void) {
        self.file = file
        self.store = store
        self.onClose = onClose
        self._rawContent = State(initialValue: file.originalText)
    }

    /// The raw text the editor was seeded with. Useful for tests and previews.
    public var initialRawContent: String { file.originalText }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("cancel") { onClose() }
                    .font(Typography.systemMono(size: 13))
                    .foregroundStyle(LCDPalette.textDim)
                Spacer()
                Text(file.fileURL.lastPathComponent)
                    .font(Typography.systemMono(size: 12))
                    .foregroundStyle(LCDPalette.textDim)
                Spacer()
                Button("save") {
                    let text = rawContent
                    Task {
                        await save(rawContent: text)
                        onClose()
                    }
                }
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
            }
            .padding(12)
            .background(LCDPalette.chromeDark)

            TextEditor(text: $rawContent)
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
                .scrollContentBackground(.hidden)
                .background(LCDPalette.bgWarm)
        }
        .background(LCDPalette.bgWarm)
        .ignoresSafeArea(.container, edges: .horizontal)
    }

    func save(rawContent: String) async {
        guard let parsed = try? BotFile(fileURL: file.fileURL, text: rawContent) else {
            return  // malformed input — keep editor open for user to fix; v1 silent.
        }
        try? await store.write(parsed)
    }
}
