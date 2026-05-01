import Foundation
import FoundationModels

/// The output of `ContextAssembler.assemble(mode:)`.
///
/// Every model call goes through one of these. `LiveLanguageModelClient`
/// constructs a fresh `LanguageModelSession` from `tools` and `systemInstructions`
/// (sessions are short-lived per PRD §3.3) and calls `respond(to: userPrompt,
/// generating: Output.self)`.
///
/// `budget` and `loadedFiles` are diagnostics — never sent to the model. They
/// power DEBUG logging and (for `loadedFiles`) the `state_delta` field of
/// journal entries.
public struct AssembledContext: Sendable {
    public let systemInstructions: String
    public let userPrompt: String
    public let tools: [any Tool]
    public let budget: TokenBudget
    public let loadedFiles: [String]

    public init(
        systemInstructions: String,
        userPrompt: String,
        tools: [any Tool],
        budget: TokenBudget,
        loadedFiles: [String]
    ) {
        self.systemInstructions = systemInstructions
        self.userPrompt = userPrompt
        self.tools = tools
        self.budget = budget
        self.loadedFiles = loadedFiles
    }
}
