import Foundation
import FoundationModels
import OSLog
import b0tBrain

/// Wraps Apple's `LanguageModelSession` for production use.
///
/// Per PRD §3.3, every model call is a fresh session — sessions are not
/// retained across user turns. The init checks `SystemLanguageModel.default`
/// availability and throws `.modelUnavailable` if Apple Intelligence is
/// disabled or the model isn't ready; callers (`DebugBrainView` in Phase 2,
/// `Home/` views in Phase 4) decide how to surface that.
///
/// Generation errors are mapped to `LanguageModelClientError`:
/// - `.exceededContextWindowSize` → `.exceededContextWindowSize`
/// - `.decodingFailure` → `.malformedGenerableOutput`
/// - `.assetsUnavailable` → `.modelUnavailable`
/// - all others → `.sessionFailed` (case name logged at error level)
///
/// T9 (Phase 3): `generate` now returns `(Output, [ToolCallRecord])`. After the
/// `respond` call, `extractToolCallRecords(from:)` walks the session's
/// `Transcript` (a `RandomAccessCollection<Transcript.Entry>`) looking for
/// `.toolCalls` and `.toolOutput` entries. It matches them by `id` — each
/// `Transcript.ToolCall` and `Transcript.ToolOutput` share a common `id` string
/// — to produce one `ToolCallRecord` per tool invocation without colliding when
/// the same tool is called more than once in a single turn.
///
/// `Transcript` is the top-level `FoundationModels.Transcript` type (confirmed
/// from the iOS 26 swiftinterface — `session.transcript` returns `Transcript`,
/// not `LanguageModelSession.Transcript`).
///
/// See spec §5.3.
public struct FoundationModelsEngine: InferenceEngine {
    private static let logger = Logger(
        subsystem: "com.toppeross.b0t.b0tCore",
        category: "LiveLanguageModelClient"
    )

    /// Apple's on-device Foundation Models window.
    ///
    /// The FoundationModels framework does not expose a query API for the actual
    /// context length of `SystemLanguageModel.default`, so this is set to the
    /// documented 4096-token window for the 3B on-device model. Update if Apple
    /// revises the model or exposes a programmatic accessor.
    public var contextWindow: Int { 4096 }

    public init() throws {
        guard SystemLanguageModel.default.isAvailable else {
            Self.logger.error(
                "LiveLanguageModelClient init failed: SystemLanguageModel not available — \(String(describing: SystemLanguageModel.default.availability))"
            )
            throw LanguageModelClientError.modelUnavailable
        }
    }

    public func generate<Output: StructuredOutput>(
        context: AssembledContext,
        generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord]) {
        let session = LanguageModelSession(
            model: .default,
            tools: context.tools,
            instructions: {
                Instructions(context.systemInstructions)
            }
        )

        do {
            let response = try await session.respond(
                to: context.userPrompt,
                generating: outputType
            )
            let records = Self.extractToolCallRecords(from: session.transcript)
            return (response.content, records)
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                throw LanguageModelClientError.exceededContextWindowSize(
                    estimatedTokens: context.budget.estimated
                )
            case .decodingFailure:
                throw LanguageModelClientError.malformedGenerableOutput(
                    underlyingDescription: String(describing: error)
                )
            case .assetsUnavailable:
                throw LanguageModelClientError.modelUnavailable
            default:
                Self.logger.error("unhandled GenerationError: \(String(describing: error))")
                throw LanguageModelClientError.sessionFailed(
                    underlyingDescription: String(describing: error)
                )
            }
        } catch {
            throw LanguageModelClientError.sessionFailed(
                underlyingDescription: String(describing: error)
            )
        }
    }

    /// Walks the session transcript after generation and constructs one
    /// `ToolCallRecord` per tool invocation.
    ///
    /// `Transcript` is `RandomAccessCollection<Transcript.Entry>`. Each entry
    /// is one of: `.instructions`, `.prompt`, `.toolCalls`, `.toolOutput`,
    /// `.response`. We pair `.toolCalls` entries (the model's invocation
    /// request) with `.toolOutput` entries (the tool's result) by matching on
    /// the shared `id` field — `Transcript.ToolCall.id` and
    /// `Transcript.ToolOutput.id` are set to the same value by the framework.
    ///
    /// Pairing by `id` (not `toolName`) is essential for multi-call turns: if
    /// the model invokes the same tool twice (e.g., calendar.upcoming_events
    /// for two different windows), a by-name lookup would silently overwrite
    /// the first output with the second. Slices 4–6 introduce tools that may
    /// be called multiple times per turn, so correctness here matters now.
    ///
    /// **Argument summary:** `GeneratedContent.jsonString` produces compact JSON
    /// like `{"windowHours":24}`, which is more readable than the verbose
    /// `CustomDebugStringConvertible` form. Slices 4–6 will replace this with
    /// typed per-Tool `summarize(_:)` once argument summarisation is wired through.
    /// **Output summary:** `Transcript.Segment` is `CustomStringConvertible`;
    /// we join all segments' descriptions with a space.
    private static func extractToolCallRecords(from transcript: Transcript) -> [ToolCallRecord] {
        // Pair tool calls with their outputs by id. The Apple FoundationModels
        // Transcript exposes Transcript.ToolCall.id and Transcript.ToolOutput.id;
        // matching by name would silently collide when the same tool is called
        // twice in one turn (e.g., calendar.upcoming_events for two windows),
        // overwriting earlier outputs. Phase 3's T9 ships only one tool, so a
        // collision is unlikely today, but Slices 4–6 add tools that may be
        // called multiple times per turn.
        var outputByID: [String: String] = [:]
        for entry in transcript {
            if case .toolOutput(let toolOutput) = entry {
                let summary = toolOutput.segments
                    .map { String(describing: $0) }
                    .joined(separator: " ")
                outputByID[toolOutput.id] = summary
            }
        }

        var records: [ToolCallRecord] = []
        let timestamp = Date()

        for entry in transcript {
            if case .toolCalls(let toolCalls) = entry {
                for call in toolCalls {
                    let outputSummary = outputByID[call.id] ?? "(no output)"
                    records.append(
                        ToolCallRecord(
                            toolName: call.toolName,
                            argumentsSummary: argumentsSummary(call.arguments),
                            outputSummary: outputSummary,
                            timestamp: timestamp
                        )
                    )
                }
            }
        }

        return records
    }

    /// Best-effort human-readable rendering of a tool call's `GeneratedContent`
    /// arguments. `GeneratedContent.jsonString` produces compact JSON like
    /// `{"windowHours":24}`, which is far more readable than
    /// `String(describing:)` whose output looks like
    /// `"GeneratedContent(structure([...]))"`. Slices 4–6 will replace this
    /// with each Tool's typed `summarize(_:)` once per-Tool argument
    /// summarisation is wired through.
    private static func argumentsSummary(_ arguments: GeneratedContent) -> String {
        arguments.jsonString
    }
}

/// Transition alias — `b0tApp` constructs `LiveLanguageModelClient()`.
public typealias LiveLanguageModelClient = FoundationModelsEngine
