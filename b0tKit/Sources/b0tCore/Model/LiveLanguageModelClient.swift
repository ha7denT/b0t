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
/// `.toolCalls` and `.toolOutput` entries. It matches them by tool name to
/// produce one `ToolCallRecord` per tool invocation.
///
/// `Transcript` is the top-level `FoundationModels.Transcript` type (confirmed
/// from the iOS 26 swiftinterface — `session.transcript` returns `Transcript`,
/// not `LanguageModelSession.Transcript`).
///
/// See spec §5.3.
public struct LiveLanguageModelClient: LanguageModelClient {
    private static let logger = Logger(
        subsystem: "com.toppeross.b0t.b0tCore",
        category: "LiveLanguageModelClient"
    )

    public init() throws {
        guard SystemLanguageModel.default.isAvailable else {
            Self.logger.error(
                "LiveLanguageModelClient init failed: SystemLanguageModel not available — \(String(describing: SystemLanguageModel.default.availability))"
            )
            throw LanguageModelClientError.modelUnavailable
        }
    }

    public func generate<Output: Generable>(
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
    /// request) with the subsequent `.toolOutput` entries (the tool's result)
    /// by matching on `toolName`.
    ///
    /// If the SDK evolves to provide a richer pairing API, replace this
    /// linear walk. For now, we build a lookup by tool name from all
    /// `.toolOutput` entries and match them against `.toolCalls` entries.
    ///
    /// **Argument summary:** `GeneratedContent` is `CustomDebugStringConvertible`;
    /// we use `String(describing:)` to produce a compact human-readable string.
    /// **Output summary:** `Transcript.Segment` is `CustomStringConvertible`;
    /// we join all segments' descriptions with a space.
    private static func extractToolCallRecords(from transcript: Transcript) -> [ToolCallRecord] {
        // Build a map from tool name → output segments string from all toolOutput entries.
        var outputByToolName: [String: String] = [:]
        for entry in transcript {
            if case .toolOutput(let toolOutput) = entry {
                let summary = toolOutput.segments.map { String(describing: $0) }.joined(separator: " ")
                outputByToolName[toolOutput.toolName] = summary
            }
        }

        var records: [ToolCallRecord] = []
        let timestamp = Date()

        for entry in transcript {
            if case .toolCalls(let toolCalls) = entry {
                for call in toolCalls {
                    let argSummary = String(describing: call.arguments)
                    let outputSummary = outputByToolName[call.toolName] ?? "(no output)"
                    records.append(
                        ToolCallRecord(
                            toolName: call.toolName,
                            argumentsSummary: argSummary,
                            outputSummary: outputSummary,
                            timestamp: timestamp
                        ))
                }
            }
        }

        return records
    }
}
