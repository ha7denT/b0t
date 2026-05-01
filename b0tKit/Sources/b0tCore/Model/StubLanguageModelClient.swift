import Foundation
import FoundationModels

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
public struct StubLanguageModelClient: LanguageModelClient {
    public typealias Handler = @Sendable (AssembledContext, any Generable.Type) throws -> Any

    private let handler: Handler

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    public func generate<Output: Generable>(
        context: AssembledContext,
        generating outputType: Output.Type
    ) async throws -> Output {
        let raw = try handler(context, outputType)
        guard let typed = raw as? Output else {
            throw LanguageModelClientError.malformedGenerableOutput(
                underlyingDescription: "stub returned \(type(of: raw)) for \(outputType)"
            )
        }
        return typed
    }
}
