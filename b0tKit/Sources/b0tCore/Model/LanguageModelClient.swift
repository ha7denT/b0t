import Foundation
import FoundationModels
import b0tBrain

/// The seam through which `b0tCore` talks to a language model engine.
///
/// Engine-agnostic as of the 2026-05-29 amendment (ADR-0012). Conformers:
/// `FoundationModelsEngine` (Apple `LanguageModelSession`) and, from Stage B,
/// a llama.cpp-backed engine. Production code is identical against either;
/// tests use `StubInferenceEngine`.
///
/// `generate` returns `(Output, [ToolCallRecord])`. The records capture tool
/// invocations during generation. `Output` is `StructuredOutput` (refines
/// `Generable`, adds `Codable`) so both engines can populate the same type.
public protocol InferenceEngine: Sendable {
    func generate<Output: StructuredOutput>(
        context: AssembledContext,
        generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord])
}

/// Transition alias — existing call sites in `b0tApp` and tests refer to
/// `LanguageModelClient`. Remove in a later cleanup once references migrate.
public typealias LanguageModelClient = InferenceEngine

/// Errors surfaced by any `InferenceEngine` implementation.
///
/// `modelUnavailable` is raised by `FoundationModelsEngine` at init time when
/// `SystemLanguageModel.default.isAvailable == false`.
///
/// `exceededContextWindowSize` carries the assembler's pre-call estimate so the
/// graduated fallback in `ContextAssembler` can log which budget level fired.
public enum InferenceEngineError: Error, Sendable, Equatable {
    case modelUnavailable
    case exceededContextWindowSize(estimatedTokens: Int)
    case sessionFailed(underlyingDescription: String)
    case malformedGenerableOutput(underlyingDescription: String)
}

/// Transition alias for the renamed error enum.
public typealias LanguageModelClientError = InferenceEngineError
