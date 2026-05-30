import Foundation
import FoundationModels
import b0tBrain

/// A test seam for `LanguageModelClient`. Constructed test-by-test with a
/// closure that maps `(AssembledContext, Output.Type)` to an `Any` result.
///
/// The stub does no orchestration — it doesn't honour `tools`, doesn't emit
/// streaming chunks, doesn't model rate-limiting. It exists so we can test
/// the *pipeline* (assembler → executor → journal) without involving the
/// real model. Tests that need to exercise model errors throw from the
/// closure. Tests that need to exercise specific outputs return them.
///
/// Typed-result mismatch (the closure returns a value of a different
/// `Generable` type from the one requested) is reported as
/// `LanguageModelClientError.malformedGenerableOutput` rather than a crash —
/// it would otherwise be a silent bug in the test, not an assertion failure.
///
/// T9 (Phase 3): handlers may return a bare `Generable` value (existing
/// behaviour, zero records emitted) *or* a `HandlerResult` wrapping a value
/// plus scripted `[ToolCallRecord]`. Existing tests require no changes.
public struct StubInferenceEngine: InferenceEngine {
    public typealias Handler = @Sendable (AssembledContext, any Generable.Type) throws -> Any

    /// Optional wrapper that lets a test script both the output value and the
    /// tool-call records returned by `generate`. Tests that don't care about
    /// records simply return the bare value; the stub defaults `records` to `[]`.
    ///
    /// `value` is `Any` so the malformed-type test path still works (the handler
    /// can return a value of an unexpected type to exercise the error branch).
    ///
    /// `@unchecked Sendable`: `value: Any` cannot statically prove `Sendable`
    /// conformance, but `HandlerResult` is constructed and consumed on the same
    /// task in tests. The test's own discipline keeps it safe.
    public struct HandlerResult: @unchecked Sendable {
        public let value: Any
        public let toolCalls: [ToolCallRecord]
        public init(value: Any, toolCalls: [ToolCallRecord]) {
            self.value = value
            self.toolCalls = toolCalls
        }
    }

    private let handler: Handler

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    public func generate<Output: StructuredOutput>(
        context: AssembledContext,
        generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord]) {
        let raw = try handler(context, outputType)
        let value: Any
        let records: [ToolCallRecord]
        if let wrapped = raw as? HandlerResult {
            value = wrapped.value
            records = wrapped.toolCalls
        } else {
            value = raw
            records = []
        }
        guard let typed = value as? Output else {
            throw LanguageModelClientError.malformedGenerableOutput(
                underlyingDescription: "stub returned \(type(of: value)) for \(outputType)"
            )
        }
        return (typed, records)
    }
}

/// Transition alias — existing tests construct `StubLanguageModelClient(handler:)`.
public typealias StubLanguageModelClient = StubInferenceEngine
