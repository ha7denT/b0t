import Foundation
import b0tBrain
import b0tCore

/// `InferenceEngine` backed by a local GGUF model via `LlamaRuntime`.
///
/// Stage B: no tools (`records` always empty). Structured output is enforced by
/// the type's pre-generated GBNF grammar and decoded from JSON via `Codable`.
public struct LlamaEngine: InferenceEngine {
    private let runtime: LlamaRuntime

    public var contextWindow: Int { runtime.contextWindow }

    public init(modelPath: URL, contextLength: Int) throws {
        self.runtime = try LlamaRuntime(modelPath: modelPath, contextLength: contextLength)
    }

    public func generate<Output: StructuredOutput>(
        context: AssembledContext,
        generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord]) {
        // llama.cpp does not inject the schema, so describe the shape in-prompt.
        let userContent = """
            \(context.userPrompt)

            Respond with ONLY a JSON object and nothing else. \(Output.jsonShapeHint)
            """
        let messages = [
            LlamaChatMessage(role: "system", content: context.systemInstructions),
            LlamaChatMessage(role: "user", content: userContent),
        ]
        let raw = try await runtime.generate(
            messages: messages,
            grammar: Output.gbnfGrammar.isEmpty ? nil : Output.gbnfGrammar,
            maxTokens: 512
        )
        guard let data = Self.firstJSONObject(in: raw)?.data(using: .utf8) else {
            throw InferenceEngineError.malformedGenerableOutput(
                underlyingDescription: "no JSON object in llama output: \(raw.prefix(200))")
        }
        do {
            let value = try JSONDecoder().decode(Output.self, from: data)
            return (value, [])
        } catch {
            throw InferenceEngineError.malformedGenerableOutput(
                underlyingDescription: String(describing: error))
        }
    }

    /// Extracts the first balanced `{...}` span — defensive against models that
    /// wrap JSON in prose despite the grammar (and against grammar-off fallback).
    static func firstJSONObject(in text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var idx = start
        while idx < text.endIndex {
            let c = text[idx]
            if c == "{" { depth += 1 }
            if c == "}" {
                depth -= 1
                if depth == 0 { return String(text[start...idx]) }
            }
            idx = text.index(after: idx)
        }
        return nil
    }
}
