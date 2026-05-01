import Foundation
import FoundationModels

/// Phase 2 slice 1 placeholder.
///
/// Slice 2 (Task 6) replaces this with the full struct (system instructions,
/// user prompt, tools array, token budget, loaded files). The intermediate
/// shape exists only so `LanguageModelClient` compiles in slice 1.
public struct AssembledContext: Sendable {
    public let userPrompt: String
    public let tools: [any Tool]

    public init(userPrompt: String, tools: [any Tool] = []) {
        self.userPrompt = userPrompt
        self.tools = tools
    }
}
