import Foundation
import FoundationModels
import b0tBrain

/// The seam through which `b0tCore` talks to a language model.
///
/// Two implementations exist: `LiveLanguageModelClient` (wraps Apple's
/// `LanguageModelSession`) and `StubLanguageModelClient` (test-target visible).
/// Production code is identical against either; tests shape the stub's
/// outputs per case. See `docs/specs/phase-2-foundation-models-loop.md` §5.3.
///
/// T9 (Phase 3): `generate` now returns `(Output, [ToolCallRecord])`. The records
/// array captures tool invocations that occurred during the generation. Production
/// callers drop the records with `_` until T10/T12 wire them into `ConversationTurn`
/// and `TickResult`. `LiveLanguageModelClient` returns `[]` until the
/// `LanguageModelSession.Transcript` API exposes iterable tool-call entries
/// (see `LiveLanguageModelClient.extractToolCallRecords` for fallback rationale).
public protocol LanguageModelClient: Sendable {
    func generate<Output: Generable>(
        context: AssembledContext,
        generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord])
}

/// Errors surfaced by any `LanguageModelClient` implementation.
///
/// `modelUnavailable` is raised by `LiveLanguageModelClient` at init time when
/// `SystemLanguageModel.default.isAvailable == false` (Apple Intelligence
/// disabled, device ineligible, model not yet downloaded, etc.).
///
/// `exceededContextWindowSize` carries the assembler's pre-call estimate so
/// the graduated fallback in `ContextAssembler` (spec §7.4) can log which
/// budget level triggered the fallback.
public enum LanguageModelClientError: Error, Sendable, Equatable {
    case modelUnavailable
    case exceededContextWindowSize(estimatedTokens: Int)
    case sessionFailed(underlyingDescription: String)
    case malformedGenerableOutput(underlyingDescription: String)
}
