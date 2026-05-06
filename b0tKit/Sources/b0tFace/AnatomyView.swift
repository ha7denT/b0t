import SpriteKit
import SwiftUI

/// SwiftUI wrapper that hosts an `AnatomyScene` inside a `SpriteView`.
///
/// Phase 4 binds the scene to a parent `AnatomyState` (Slice 4); for now the scene
/// is constructed once and Hilfer is installed.
public struct AnatomyView: View {
    @State private var scene: AnatomyScene = {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        scene.installHilferFace()
        return scene
    }()

    public init() {}

    public var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .ignoresSafeArea(.container, edges: .horizontal)
    }
}

#Preview("anatomy — hilfer static") {
    AnatomyView()
        .frame(maxWidth: .infinity, maxHeight: 480)
        .background(Color(red: 0.09, green: 0.08, blue: 0.06))
}
