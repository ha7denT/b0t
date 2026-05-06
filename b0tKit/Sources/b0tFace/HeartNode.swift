import SpriteKit

/// The heart — distinguished bottom-centre organ. Pulses at the BPM declared in
/// `heartbeat/schedule.md`. When paused (trial expired, quiet hours), pulse stops.
public final class HeartNode {
    public let node: SKNode

    public init(textureName: String) {
        let texture = SKTexture(imageNamed: textureName)
        texture.filteringMode = .nearest
        let sprite = SKSpriteNode(texture: texture, size: AnatomyLayout.heartSize)
        sprite.name = OrganID.heart.rawValue
        self.node = sprite
    }

    /// Start (or restart) the heartbeat at the given BPM (beats per minute).
    /// Phase 4 BPM range is 1–12 per spec §4.6 semantic registry; range enforced upstream.
    public func startPulsing(bpm: Int) {
        node.removeAction(forKey: "heartbeat")
        let interval = 60.0 / max(1.0, Double(bpm))
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.10, duration: 0.12),
            SKAction.scale(to: 1.0, duration: 0.20),
            SKAction.wait(forDuration: max(0.05, interval - 0.32)),
        ])
        node.run(SKAction.repeatForever(pulse), withKey: "heartbeat")
    }

    public func pause() {
        node.removeAction(forKey: "heartbeat")
        node.setScale(1.0)
    }
}
