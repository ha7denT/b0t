import SpriteKit
import SwiftUI

/// SwiftUI wrapper that hosts an `AnatomyScene` inside a `SpriteView`.
///
/// Phase 4 binds the scene to a parent `AnatomyState` (Slice 4); for now the scene
/// is constructed once and the full anatomy is installed.
public struct AnatomyView: View {
    @State private var scene: AnatomyScene = {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 540))
        scene.installFullAnatomy(initialBPM: 4)
        return scene
    }()

    public init() {}

    public var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .ignoresSafeArea(.container, edges: .horizontal)
    }
}

#Preview("anatomy — full (hilfer + organs + heart + wiring)") {
    AnatomyView()
        .frame(maxWidth: .infinity, maxHeight: 540)
        .background(Color(red: 0.09, green: 0.08, blue: 0.06))
}
