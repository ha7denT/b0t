import FoundationModels
import XCTest

@testable import b0tCore

final class DecisionsTests: XCTestCase {
    func test_conversationResponse_equality() {
        let a = ConversationResponse(
            text: "hello",
            mood: .delighted,
            memoryObservations: [
                MemoryObservation(about: "Hayden", what: "likes coffee", importance: .medium)
            ]
        )
        let b = ConversationResponse(
            text: "hello",
            mood: .delighted,
            memoryObservations: [
                MemoryObservation(about: "Hayden", what: "likes coffee", importance: .medium)
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
        XCTAssertEqual(
            MoodTag.allCases,
            [
                .idle, .speaking, .thinking, .surprised,
                .sleepy, .attentive, .worried, .delighted,
            ]
        )
    }

    func test_tickDecision_defaultArguments() {
        let d = TickDecision(
            observed: "afternoon",
            considered: ["pass", "glance_calendar"],
            decided: "pass",
            why: "nothing urgent",
            acted: "noted silently"
        )
        XCTAssertNil(d.mood)
        XCTAssertNil(d.organUsed)
        XCTAssertTrue(d.memoryObservations.isEmpty)
    }

    func test_tickDecision_equality() {
        let a = TickDecision(
            observed: "x", considered: ["y"], decided: "y", why: "z", acted: "w",
            mood: .attentive, organUsed: "calendar",
            memoryObservations: [MemoryObservation(about: "a", what: "b", importance: .low)]
        )
        let b = TickDecision(
            observed: "x", considered: ["y"], decided: "y", why: "z", acted: "w",
            mood: .attentive, organUsed: "calendar",
            memoryObservations: [MemoryObservation(about: "a", what: "b", importance: .low)]
        )
        XCTAssertEqual(a, b)
    }

    func test_relationshipNote_equality() {
        let a = RelationshipNote(name: "Sam", relation: "spouse", notes: "likes coffee")
        let b = RelationshipNote(name: "Sam", relation: "spouse", notes: "likes coffee")
        XCTAssertEqual(a, b)
    }

    func test_moodTransition_equality() {
        let a = MoodTransition(from: .idle, to: .delighted, why: "user said hello warmly")
        let b = MoodTransition(from: .idle, to: .delighted, why: "user said hello warmly")
        XCTAssertEqual(a, b)
    }
}
