import Foundation

/// The single generation primitive `LlamaEngine` needs, abstracted so the
/// two-pass tool-call loop is testable without loading a real model.
/// `LlamaRuntime` is the production conformer.
public protocol LlamaGenerating: Sendable {
    var contextWindow: Int { get }
    func generate(
        messages: [LlamaChatMessage], grammar: String?, maxTokens: Int
    ) async throws -> String
}
