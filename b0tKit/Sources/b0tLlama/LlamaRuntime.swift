import Foundation
import llama

/// Thin b0t-owned wrapper over the llama.cpp C API. Loads one GGUF model and
/// its context, applies the model's embedded chat template, and generates text
/// — optionally constrained by a GBNF grammar. One resident model per instance.
///
/// An `actor` so the non-Sendable C context pointers never cross threads
/// unsynchronised. Model/context are freed in `deinit`.
public actor LlamaRuntime {
    /// The model's trained context length (from GGUF metadata), used as the
    /// token-budget denominator by callers.
    public nonisolated let contextWindow: Int

    /// Loads `modelPath` and creates a context of `contextLength` tokens
    /// (clamped to the model's trained maximum).
    public init(modelPath: URL, contextLength: Int) throws {
        self.contextWindow = 0
        fatalError("B1.3")
    }

    /// Applies the model's embedded chat template to `messages`, tokenizes,
    /// and generates until EOG or `maxTokens`. If `grammar` is non-nil, a GBNF
    /// grammar sampler constrains output to it (root rule "root").
    public func generate(
        messages: [LlamaChatMessage],
        grammar: String?,
        maxTokens: Int
    ) async throws -> String { fatalError("B1.3") }
}
