import Foundation

/// A role-tagged message handed to `LlamaRuntime`. Roles map to chat-template
/// roles ("system", "user", "assistant").
public struct LlamaChatMessage: Sendable, Equatable {
    public let role: String
    public let content: String
    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

/// Errors from the llama.cpp runtime wrapper.
public enum LlamaRuntimeError: Error, Sendable, Equatable {
    case modelLoadFailed(path: String)
    case contextCreationFailed
    case templateApplyFailed
    case decodeFailed(code: Int32)
    case generationTimedOut
}
