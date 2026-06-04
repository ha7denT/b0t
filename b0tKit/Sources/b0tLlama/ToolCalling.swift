import Foundation

/// An engine-neutral description of a tool the model may call. Minimal by
/// design (ADR-0018): name + human description rendered into the prompt;
/// arguments are validated only as well-formed JSON for now (per-tool argument
/// grammars are deferred to the real C3/C4 loop).
public struct ToolDescriptor: Sendable, Equatable {
    public let name: String
    public let description: String

    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}

/// A parsed tool call: which tool, and its (freeform) arguments. The GBNF
/// tool-call grammar guarantees this shape structurally, so a successful parse
/// is itself evidence of a well-formed call (ADR-0018 — format reliability is
/// the grammar's job, not the model's).
public struct ToolCallEnvelope: Codable, Equatable, Sendable {
    public let tool: String
    public let arguments: JSONValue

    public init(tool: String, arguments: JSONValue) {
        self.tool = tool
        self.arguments = arguments
    }
}

/// One row of the check-#6 fixture set: a prompt that *should* drive a specific
/// tool, and the tool we expect the model to pick.
public struct ToolCallProbe: Sendable, Equatable {
    public let prompt: String
    public let expectedTool: String

    public init(prompt: String, expectedTool: String) {
        self.prompt = prompt
        self.expectedTool = expectedTool
    }
}

/// Aggregate result of scoring a tool-call run.
public struct ToolCallScore: Sendable, Equatable {
    /// Probes attempted.
    public let total: Int
    /// Outputs that parsed into a well-formed envelope.
    public let parsed: Int
    /// Parsed calls whose chosen tool matched the expected tool.
    public let correctTool: Int

    public var parseRate: Double { total == 0 ? 0 : Double(parsed) / Double(total) }
    public var hitRate: Double { total == 0 ? 0 : Double(correctTool) / Double(total) }
}

/// Fixed b0t-representative tool descriptors + probes for the Q6 tool-call
/// check. The names mirror the shipped `b0tModules` tools, but are kept as plain
/// strings here so `b0tLlama` need not depend on `b0tModules` (layering).
public enum Q6ToolCallFixtures {
    public static let descriptors: [ToolDescriptor] = [
        .init(
            name: "calendar.upcoming_events",
            description: "List the user's upcoming calendar events."),
        .init(
            name: "reminders.create",
            description: "Create a reminder with a title and optional due time."),
        .init(
            name: "reminders.list",
            description: "List the user's current reminders."),
        .init(
            name: "health.steps_today",
            description: "Get the number of steps the user has walked today."),
        .init(
            name: "time.now",
            description: "Get the current date and time."),
    ]

    public static let probes: [ToolCallProbe] = [
        .init(prompt: "What's on my calendar tomorrow?", expectedTool: "calendar.upcoming_events"),
        .init(prompt: "Remind me to call the dentist at 3pm.", expectedTool: "reminders.create"),
        .init(prompt: "What reminders do I have right now?", expectedTool: "reminders.list"),
        .init(prompt: "How many steps have I taken today?", expectedTool: "health.steps_today"),
        .init(prompt: "What time is it?", expectedTool: "time.now"),
        .init(
            prompt: "Add 'buy milk' to my reminders.", expectedTool: "reminders.create"),
        .init(prompt: "Do I have any meetings this week?", expectedTool: "calendar.upcoming_events"),
        .init(prompt: "What's today's date?", expectedTool: "time.now"),
    ]

    /// Scores a set of (probe, parsed-envelope-or-nil) results.
    public static func score(
        _ results: [(probe: ToolCallProbe, call: ToolCallEnvelope?)]
    )
        -> ToolCallScore
    {
        let parsed = results.filter { $0.call != nil }.count
        let correct = results.filter { $0.call?.tool == $0.probe.expectedTool }.count
        return ToolCallScore(total: results.count, parsed: parsed, correctTool: correct)
    }
}
