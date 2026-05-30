import Foundation
import FoundationModels
import XCTest

@testable import b0tCore

/// Verifies the decision types passed to `InferenceEngine.generate` conform to
/// `StructuredOutput`. The generic helper only compiles if the conformance
/// exists, so this is a compile-time guarantee with a runtime assertion.
final class StructuredOutputConformanceTests: XCTestCase {

    private func accepts<T: StructuredOutput>(_ type: T.Type) -> Bool { true }

    func test_decisionTypes_areStructuredOutput() {
        XCTAssertTrue(accepts(ConversationResponse.self))
        XCTAssertTrue(accepts(TickDecision.self))
        XCTAssertTrue(accepts(MemoryObservation.self))
        XCTAssertTrue(accepts(RelationshipNote.self))
        XCTAssertTrue(accepts(MoodTransition.self))
    }
}
