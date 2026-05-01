import Foundation
import FoundationModels
import OSLog

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
/// - all others → `.sessionFailed`
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
    ) async throws -> Output {
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
            return response.content
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
            default:
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
}
