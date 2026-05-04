import Foundation
import FoundationModels

/// A coarse time-of-day bucket the model uses to anchor its replies.
///
/// Boundaries are intentionally crude (06:30 / 12:00 / 18:00 / 22:00) and
/// rendered in UTC for Phase 2 — Phase 4+ may switch to local time and
/// soften the boundaries ("late evening", "early morning", etc.).
@Generable
public enum TimeOfDay: String, Sendable, Equatable, CaseIterable {
    case morning
    case afternoon
    case evening
    case night

    public static func bucket(
        for date: Date,
        in timeZone: TimeZone = TimeZone(identifier: "UTC")!
    ) -> TimeOfDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let totalMinutes = hour * 60 + minute

        if totalMinutes >= 6 * 60 + 30 && totalMinutes < 12 * 60 {
            return .morning
        } else if totalMinutes >= 12 * 60 && totalMinutes < 18 * 60 {
            return .afternoon
        } else if totalMinutes >= 18 * 60 && totalMinutes < 22 * 60 {
            return .evening
        } else {
            return .night
        }
    }
}
