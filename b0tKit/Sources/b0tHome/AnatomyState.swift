import Foundation
import Observation

import b0tBrain
import b0tFace

/// The single @Observable source-of-truth that bridges SpriteKit scene events and
/// SwiftUI views. Mutations here drive both directions:
///
/// - SwiftUI views observe `selectedOrgan` to re-render the LCD inspection panel.
/// - The `AnatomyScene` observes `activeWiring` and `heartBPM` to play / restart
///   procedural animations.
@Observable
public final class AnatomyState {
    public var selectedOrgan: OrganID?
    public var activeWiring: Set<OrganID>
    public var heartBPM: Int
    public let bot: Bot
    public let store: BotStore

    public init(bot: Bot, store: BotStore, initialHeartBPM: Int) {
        self.bot = bot
        self.store = store
        self.selectedOrgan = nil
        self.activeWiring = []
        self.heartBPM = initialHeartBPM
    }
}
