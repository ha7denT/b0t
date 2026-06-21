import Foundation
import Observation

import b0tBrain
import b0tCore
import b0tFace

/// The two top-level home-screen modes (ADR-0019). `chat` = talking to the
/// b0t (small centred face, feed dominant); `workbench` = working on it
/// (large face + organ ring + tabbed inspector).
public enum HomeMode: Sendable, Hashable {
    case chat
    case workbench
}

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

    /// The active ConversationManager. `nil` while HomeView's .task is still
    /// loading modules + initializing the model client; views that depend on it
    /// (currently `ChatView`) check for nil and disable input until ready.
    public var manager: ConversationManager?

    /// The most recent per-turn token usage (chat or heartbeat). Drives the crown
    /// meters + Processor Controls gauge. Set by `UsageListener`.
    public var latestUsage: GenerationUsage?

    /// Injected Stage-D seams (nil in previews/tests that don't exercise them).
    public var processorController: (any ProcessorControlling)?
    public var downloadCoordinator: ModelDownloadCoordinator?

    /// Current top-level mode. Default `.chat` (ADR-0019).
    public var mode: HomeMode

    public init(bot: Bot, store: BotStore, initialHeartBPM: Int) {
        self.bot = bot
        self.store = store
        self.selectedOrgan = nil
        self.activeWiring = []
        self.heartBPM = initialHeartBPM
        self.manager = nil
        self.latestUsage = nil
        self.processorController = nil
        self.downloadCoordinator = nil
        self.mode = .chat
    }

    /// Flip chat ⇄ workbench. Clears any organ selection so workbench returns
    /// to its recent-chat zero-state rather than a stale inspector.
    public func toggleMode() {
        mode = (mode == .chat) ? .workbench : .chat
        selectedOrgan = nil
    }
}
