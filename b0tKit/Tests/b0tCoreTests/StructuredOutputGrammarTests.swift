import Foundation
import XCTest

@testable import b0tCore

final class StructuredOutputGrammarTests: XCTestCase {
    func test_grammars_areNonEmptyAndRooted() {
        let types: [any StructuredOutput.Type] = [
            ConversationResponse.self, TickDecision.self, MemoryObservation.self,
            RelationshipNote.self, MoodTransition.self,
        ]
        for t in types {
            XCTAssertFalse(t.gbnfGrammar.isEmpty, "\(t) grammar empty")
            XCTAssertTrue(t.gbnfGrammar.contains("root"), "\(t) grammar lacks root rule")
            XCTAssertFalse(t.jsonShapeHint.isEmpty, "\(t) shape hint empty")
        }
    }
}
