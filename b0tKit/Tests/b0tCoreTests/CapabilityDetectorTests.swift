import XCTest

@testable import b0tCore

/// Tests for `CapabilityDetector` — Stage C2 engine resolution.
///
/// Resolution table (C2; model-download gate is added in C4):
///   declared `foundation_models` + FM available  → .foundationModels, didFallBack = false
///   declared `foundation_models` + FM unavailable → .llama,            didFallBack = true
///   declared `llama`                              → .llama,            didFallBack = false
final class CapabilityDetectorTests: XCTestCase {
    // MARK: - foundation_models declared, FM available

    func test_declaredFM_fmAvailable_resolvesFoundationModels() {
        let result = CapabilityDetector.resolve(
            declared: .foundationModels,
            fmAvailable: true
        )
        XCTAssertEqual(result.engine, .foundationModels)
        XCTAssertFalse(result.didFallBack)
    }

    // MARK: - foundation_models declared, FM unavailable → fallback

    func test_declaredFM_fmUnavailable_fallsBackToLlama() {
        let result = CapabilityDetector.resolve(
            declared: .foundationModels,
            fmAvailable: false
        )
        XCTAssertEqual(result.engine, .llama)
        XCTAssertTrue(result.didFallBack)
    }

    // MARK: - llama declared

    func test_declaredLlama_resolvesLlama() {
        let result = CapabilityDetector.resolve(
            declared: .llama,
            fmAvailable: true  // FM state is irrelevant when llama is declared
        )
        XCTAssertEqual(result.engine, .llama)
        XCTAssertFalse(result.didFallBack)
    }

    func test_declaredLlama_fmUnavailable_stillResolvesLlama() {
        let result = CapabilityDetector.resolve(
            declared: .llama,
            fmAvailable: false
        )
        XCTAssertEqual(result.engine, .llama)
        XCTAssertFalse(result.didFallBack)
    }
}
