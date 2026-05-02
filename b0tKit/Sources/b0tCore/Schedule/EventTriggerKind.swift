import Foundation

/// Event-trigger keys recognized in `heartbeat/schedule.md` frontmatter.
///
/// Slice 6 parses the list but does not wire actual event triggers — only
/// `.scheduled` ticks fire in Phase 2. Phase 4+ adds CLLocationManager,
/// EKEventStore observation, app lifecycle, and notification observation
/// hooks that fire heartbeats with the corresponding trigger kind.
public enum EventTriggerKind: String, Sendable, Equatable, CaseIterable {
    case locationChangeSignificant = "location_change_significant"
    case calendarEventApproaching30min = "calendar_event_approaching_30min"
    case appForegrounded = "app_foregrounded"
    case notificationReceived = "notification_received"
}
