import FoundationModels
import XCTest

@testable import b0tCore

final class AssembledContextTests: XCTestCase {
    func test_tokenBudget_summedBreakdownMatchesEstimated() {
        let budget = TokenBudget(
            estimated: 600,
            limit: 3500,
            breakdown: [
                "identity": 450,
                "memory": 100,
                "userPrompt": 50,
            ],
            didFallBackToDigest: false
        )
        XCTAssertEqual(budget.estimated, 600)
        XCTAssertEqual(budget.breakdown.values.reduce(0, +), 600)
        XCTAssertFalse(budget.didFallBackToDigest)
    }

    func test_assemblyMode_conversationCarriesPrompt() {
        let mode = AssemblyMode.conversation(userPrompt: "hello")
        if case .conversation(let prompt) = mode {
            XCTAssertEqual(prompt, "hello")
        } else {
            XCTFail("expected .conversation")
        }
    }

    func test_assemblyMode_heartbeatCarriesTriggerAndGap() {
        let mode = AssemblyMode.heartbeat(trigger: .scheduled, missedGap: .seconds(7200))
        if case .heartbeat(let trigger, let gap) = mode {
            XCTAssertEqual(trigger, .scheduled)
            XCTAssertEqual(gap, .seconds(7200))
        } else {
            XCTFail("expected .heartbeat")
        }
    }

    func test_assembledContext_carriesAllFields() {
        let budget = TokenBudget(
            estimated: 100, limit: 3500, breakdown: ["x": 100], didFallBackToDigest: false
        )
        let ctx = AssembledContext(
            systemInstructions: "you are b0t-01",
            userPrompt: "hi",
            tools: [],
            budget: budget,
            loadedFiles: ["identity/core.md"]
        )
        XCTAssertEqual(ctx.systemInstructions, "you are b0t-01")
        XCTAssertEqual(ctx.userPrompt, "hi")
        XCTAssertTrue(ctx.tools.isEmpty)
        XCTAssertEqual(ctx.budget.estimated, 100)
        XCTAssertEqual(ctx.loadedFiles, ["identity/core.md"])
    }
}
