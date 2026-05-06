import b0tFace

/// Wires `AnatomyScene` tap events to `AnatomyState`. Tapping the same organ twice
/// deselects (returns LCD to chat).
enum SceneStateBridge {
    static func connect(scene: AnatomyScene, state: AnatomyState) {
        scene.tapHandler = { [weak state] organ in
            guard let state else { return }
            if state.selectedOrgan == organ {
                state.selectedOrgan = nil  // deselect on second tap
            } else {
                state.selectedOrgan = organ
            }
        }
    }
}
