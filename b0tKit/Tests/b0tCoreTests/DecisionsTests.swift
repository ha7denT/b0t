import FoundationModels
import XCTest

@testable import b0tCore

final class DecisionsTests: XCTestCase {
    func test_conversationResponse_equality() {
        let a = ConversationResponse(
            text: "hello",
            mood: .delighted,
            memoryObservations: [
                MemoryObservation(about: "Jamee", what: "likes coffee", importance: .medium)
            ]
        )
        let b = ConversationResponse(
            text: "hello",
            mood: .delighted,
            memoryObservations: [
                MemoryObservation(about: "Jamee", what: "likes coffee", importance: .medium)
            ]
        )
        XCTAssertEqual(a, b)
    }

    func test_conversationResponse_defaultArguments() {
        let r = ConversationResponse(text: "hi")
        XCTAssertNil(r.mood)
        XCTAssertTrue(r.memoryObservations.isEmpty)
    }

    func test_memoryObservation_importanceCases() {
        XCTAssertEqual(Importance.allCases, [.low, .medium, .high])
    }

    func test_moodTag_hasEightCases() {
        XCTAssertEqual(MoodTag.allCases.count, 8)
    }
}
