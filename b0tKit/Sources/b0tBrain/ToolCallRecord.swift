import Foundation

/// A record of a single tool invocation during a conversation turn or heartbeat tick.
///
/// Captured by the language-model client adapter (live or stub), threaded through
/// `ConversationManager` / `HeartbeatManager`, and surfaced in the chat log and
/// in OpenClaw journal entries' `tools_called:` sub-section.
///
/// Lives in `b0tBrain` because both `b0tCore` (the consumer that puts records
/// into `ConversationTurn`/`TickResult` and `JournalWriter`) and `b0tModules`
/// (the producer that constructs records from typed `Arguments`/`Output`)
/// already depend on `b0tBrain`. Putting the record here avoids inverting the
/// b0tCore↔b0tModules independence that Phase 2 deliberately preserved.
///
/// `argumentsSummary` and `outputSummary` are short prose intended for human
/// reading in the chat log and journal — not machine-parseable. Each tool
/// produces them from its typed `@Generable` `Arguments`/`Output`.
public struct ToolCallRecord: Sendable, Equatable {
    public let toolName: String
    public let argumentsSummary: String
    public let outputSummary: String
    public let timestamp: Date

    public init(
        toolName: String,
        argumentsSummary: String,
        outputSummary: String,
        timestamp: Date
    ) {
        self.toolName = toolName
        self.argumentsSummary = argumentsSummary
        self.outputSummary = outputSummary
        self.timestamp = timestamp
    }
}
