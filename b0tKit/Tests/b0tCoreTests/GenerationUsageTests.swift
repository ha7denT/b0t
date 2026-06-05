import XCTest
@testable import b0tCore

final class GenerationUsageTests: XCTestCase {
    func test_fractionUsed_isInputPlusOutputOverLimit() {
        let usage = GenerationUsage(
            tokensIn: 1500, tokensOut: 500, limit: 4000, modelId: "qwen3-1.7b",
            breakdown: ["identity/core.md": 800])
        XCTAssertEqual(usage.totalTokens, 2000)
        XCTAssertEqual(usage.fractionUsed, 0.5, accuracy: 0.0001)
    }

    func test_fractionUsed_zeroLimit_isZero() {
        let usage = GenerationUsage(
            tokensIn: 10, tokensOut: 10, limit: 0, modelId: "x", breakdown: [:])
        XCTAssertEqual(usage.fractionUsed, 0)
    }

    func test_modelSelectionOutcome_equatable() {
        XCTAssertEqual(ModelSelectionOutcome.active(modelId: "a"), .active(modelId: "a"))
        XCTAssertNotEqual(ModelSelectionOutcome.active(modelId: "a"), .missing(modelId: "a"))
    }
}
