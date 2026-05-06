import SwiftUI

import b0tBrain
import b0tDesign
import b0tFace

/// Lists the `.md` files in a bot directory (modules / memory / identity).
/// Tapping a file drills into `OrganInspectionView` for that file.
public struct DirectoryNavigatorView: View {
    @Bindable var state: AnatomyState
    let organ: OrganID
    let directoryRelativePath: String
    @State private var selected: BotFile?

    public init(state: AnatomyState, organ: OrganID, directoryRelativePath: String) {
        self.state = state
        self.organ = organ
        self.directoryRelativePath = directoryRelativePath
    }

    public struct Entry: Identifiable, Hashable, Sendable {
        public let id = UUID()
        public let name: String
        public let url: URL
    }

    public func entries() -> [Entry] {
        let dir = state.bot.rootURL.appending(path: directoryRelativePath)
        guard
            let urls = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil)
        else {
            return []
        }
        return
            urls
            .filter { $0.pathExtension.lowercased() == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { Entry(name: $0.lastPathComponent, url: $0) }
    }

    public var body: some View {
        if let file = selected {
            OrganInspectionView(state: state, organ: organ, file: file)
                .overlay(alignment: .topTrailing) {
                    Button("‹ list") { selected = nil }
                        .font(Typography.systemMono(size: 11))
                        .foregroundStyle(LCDPalette.textDim)
                        .padding(8)
                }
        } else {
            List(entries()) { entry in
                Button(action: {
                    let url = entry.url
                    let store = state.store
                    Task { selected = try? await store.read(url) }
                }) {
                    HStack {
                        Text(entry.name)
                            .font(Typography.systemMono(size: 13))
                            .foregroundStyle(LCDPalette.textAmber)
                        Spacer()
                    }
                }
                .listRowBackground(LCDPalette.bgWarm)
            }
            .listStyle(.plain)
            .background(LCDPalette.bgWarm)
        }
    }
}
