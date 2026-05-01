import Foundation

/// What woke the heartbeat.
///
/// Slice 5 wires `.scheduled` and `.manual`. The remaining cases are reserved
/// for Phase 4+ when real-device event triggers (significant location change,
/// calendar approaching, app foregrounded, notification received) are wired
/// through `BGTaskScheduler` event handlers.
public enum TickTrigger: String, Sendable, Equatable, CaseIterable {
    case scheduled
    case manual
    case locationChange
    case calendarApproaching
    case appForegrounded
    case notificationReceived
}
