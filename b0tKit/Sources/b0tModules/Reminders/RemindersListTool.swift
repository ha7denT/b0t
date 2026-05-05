@preconcurrency import EventKit
import Foundation
import FoundationModels
import b0tBrain
import b0tCore

/// Lists pending reminders within the given window. Completed reminders
/// are filtered out. The window parameter is currently advisory — the
/// fetched set is always the full incomplete-reminders predicate; window
/// filtering refinement is deferred (slice 5 keeps the fetcher simple,
/// per spec §6.3).
public struct RemindersListTool: Tool, PermissionAware, Sendable {
    public let name = "reminders.list"
    public let description =
        "Lists pending reminders within the given window. Completed reminders are excluded."
    public var requiresPermission: Bool { true }

    @Generable
    public enum ReminderWindow: Sendable {
        case overdue
        case today
        case nextNHours(Int)
    }

    @Generable
    public struct Arguments: Sendable {
        @Guide(description: "Filter window. Defaults to .today.")
        public let window: ReminderWindow?
        public init(window: ReminderWindow? = nil) { self.window = window }
    }

    @Generable
    public struct Output: Sendable {
        public let reminders: [Reminder]
        public let permissionDenied: Bool
        public init(reminders: [Reminder], permissionDenied: Bool) {
            self.reminders = reminders
            self.permissionDenied = permissionDenied
        }
    }

    @Generable
    public struct Reminder: Sendable {
        public let id: String
        public let title: String
        public let dueDateISO: String?
        public let listName: String

        public init(id: String, title: String, dueDateISO: String?, listName: String) {
            self.id = id
            self.title = title
            self.dueDateISO = dueDateISO
            self.listName = listName
        }
    }

    private let store: any EventKitStore
    private let gate: PermissionGate

    package init(store: any EventKitStore, gate: PermissionGate) {
        self.store = store
        self.gate = gate
    }

    public func call(arguments: Arguments) async throws -> Output {
        guard await gate.ensure(.reminders) else {
            return Output(reminders: [], permissionDenied: true)
        }

        let predicate = store.predicateForReminders(in: nil)
        let raw = await store.fetchReminders(matching: predicate)
        // Emit ISO-8601 in local timezone with offset (e.g.
        // "2026-05-05T17:00:00+10:00") rather than UTC. Same instant; the
        // wall-clock numerals match what the user sees in Reminders.app.
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        formatter.timeZone = .current
        let incomplete = raw.filter { !$0.isCompleted }

        let reminders = incomplete.map { ek in
            let dueISO: String?
            if let comps = ek.dueDateComponents,
                let date = Calendar.current.date(from: comps)
            {
                dueISO = formatter.string(from: date)
            } else {
                dueISO = nil
            }
            return Reminder(
                id: ek.calendarItemIdentifier,
                title: ek.title ?? "(untitled)",
                dueDateISO: dueISO,
                listName: ek.calendar?.title ?? ""
            )
        }

        return Output(reminders: reminders, permissionDenied: false)
    }
}

extension RemindersListTool {
    public static func summarize(_ a: Arguments) -> String {
        switch a.window {
        case .none: return "window: today"
        case .some(.overdue): return "window: overdue"
        case .some(.today): return "window: today"
        case .some(.nextNHours(let n)): return "window: next \(n)h"
        }
    }

    public static func summarize(_ o: Output) -> String {
        o.permissionDenied
            ? "permissionDenied: true"
            : "\(o.reminders.count) reminders"
    }
}
