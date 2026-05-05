@preconcurrency import EventKit
import Foundation
import FoundationModels
import b0tBrain
import b0tCore

/// Creates a reminder. Title required; dueDate, notes, and listName are
/// optional. Resolves listName to the matching `EKCalendar` (type
/// `.reminder`); if none matches, falls back to the system's
/// default-for-new-reminders calendar.
///
/// Returns `permissionDenied: true` if reminders access is not granted.
/// Returns `saveError` if the underlying `EKEventStore.save(_:commit:)`
/// throws (rare; usually database-level issues).
public struct RemindersCreateTool: Tool, PermissionAware, Sendable {
    public let name = "reminders.create"
    public let description = "Creates a reminder. Title required; dueDate, notes, and listName optional."
    public var requiresPermission: Bool { true }

    @Generable
    public struct Arguments: Sendable {
        public let title: String
        @Guide(
            description:
                "ISO-8601 due date with timezone offset in the user's local timezone (e.g. '2026-05-04T16:00:00+10:00' for 4pm Sydney time). Use the offset that matches the user's timezone — do not use UTC unless the user explicitly says UTC. Omit for no due date."
        )
        public let dueDateISO: String?
        @Guide(description: "Optional notes attached to the reminder.")
        public let notes: String?
        @Guide(description: "Reminders list name. Defaults to the module's configured default_list.")
        public let listName: String?

        public init(title: String, dueDateISO: String? = nil, notes: String? = nil, listName: String? = nil) {
            self.title = title
            self.dueDateISO = dueDateISO
            self.notes = notes
            self.listName = listName
        }
    }

    @Generable
    public struct Output: Sendable {
        public let reminderID: String?
        public let listName: String
        public let permissionDenied: Bool
        public let saveError: String?
        public init(reminderID: String?, listName: String, permissionDenied: Bool, saveError: String?) {
            self.reminderID = reminderID
            self.listName = listName
            self.permissionDenied = permissionDenied
            self.saveError = saveError
        }
    }

    private let store: any EventKitStore
    private let gate: PermissionGate
    private let defaultListName: String

    package init(store: any EventKitStore, gate: PermissionGate, defaultListName: String) {
        self.store = store
        self.gate = gate
        self.defaultListName = defaultListName
    }

    public func call(arguments: Arguments) async throws -> Output {
        guard await gate.ensure(.reminders) else {
            return Output(
                reminderID: nil,
                listName: arguments.listName ?? defaultListName,
                permissionDenied: true,
                saveError: nil
            )
        }

        let requestedName = arguments.listName ?? defaultListName
        let calendars = store.calendars(for: .reminder)
        let chosen = calendars.first { $0.title == requestedName } ?? store.defaultCalendarForNewReminders()

        guard let calendar = chosen else {
            return Output(
                reminderID: nil,
                listName: requestedName,
                permissionDenied: false,
                saveError: "no reminders calendar available"
            )
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = arguments.title
        reminder.calendar = calendar
        if let iso = arguments.dueDateISO, let date = formatter.date(from: iso) {
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            )
            reminder.dueDateComponents = comps
        }
        if let notes = arguments.notes {
            reminder.notes = notes
        }

        do {
            try store.save(reminder, commit: true)
            return Output(
                reminderID: reminder.calendarItemIdentifier,
                listName: calendar.title,
                permissionDenied: false,
                saveError: nil
            )
        } catch {
            return Output(
                reminderID: nil,
                listName: calendar.title,
                permissionDenied: false,
                saveError: String(describing: error)
            )
        }
    }
}

extension RemindersCreateTool {
    public static func summarize(_ a: Arguments) -> String {
        "title: \"\(a.title)\", list: \(a.listName ?? "default")"
    }
    public static func summarize(_ o: Output) -> String {
        if o.permissionDenied { return "permissionDenied: true" }
        if let err = o.saveError { return "saveError: \(err)" }
        return "saved to \(o.listName)"
    }
}
