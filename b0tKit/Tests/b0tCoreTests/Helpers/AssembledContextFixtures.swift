import Foundation
import FoundationModels
@testable import b0tCore

extension AssembledContext {
    /// Minimal `AssembledContext` for unit tests that need to call a
    /// `LanguageModelClient` without driving the full `ContextAssembler`
    /// path. Used across T9–T13 and T16 stub-driven tests.
    static func testFixture(userPrompt: String) -> AssembledContext {
        AssembledContext(
            systemInstructions: "",
            userPrompt: userPrompt,
            tools: [],
            budget: TokenBudget(estimated: 0, limit: 3500, breakdown: [:], didFallBackToDigest: false),
            loadedFiles: []
        )
    }
}
