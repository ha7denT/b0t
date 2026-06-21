import Foundation
import XCTest

@testable import b0tCore

/// JSON Codable round-trip for every decision type. This is the path the
/// Stage B llama engine will use to decode grammar-constrained model output,
/// so the encode→decode identity must hold for all of them.
final class CodableRoundTripTests: XCTestCase {

    private func jsonRoundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func test_moodTag_codableRoundTrips() throws {
        for tag in MoodTag.allCases {
            XCTAssertEqual(try jsonRoundTrip(tag), tag)
        }
    }

    func test_importance_codableRoundTrips() throws {
        for value in Importance.allCases {
            XCTAssertEqual(try jsonRoundTrip(value), value)
        }
    }

    func test_memoryObservation_codableRoundTrips() throws {
        let original = MemoryObservation(about: "Hayden", what: "likes coffee", importance: .high)
        XCTAssertEqual(try jsonRoundTrip(original), original)
    }

    func test_conversationResponse_codableRoundTrips() throws {
        let original = ConversationResponse(
            text: "hello",
            mood: .delighted,
            memoryObservations: [
                MemoryObservation(about: "Hayden", what: "likes coffee", importance: .medium)
            ]
        )
        XCTAssertEqual(try jsonRoundTrip(original), original)
    }

    func test_tickDecision_codableRoundTrips() throws {
        let original = TickDecision(
            observed: "afternoon",
            considered: ["pass", "glance_calendar"],
            decided: "pass",
            why: "nothing urgent",
            acted: "noted silently",
            mood: .attentive,
            organUsed: "calendar",
            memoryObservations: [MemoryObservation(about: "x", what: "y", importance: .low)]
        )
        XCTAssertEqual(try jsonRoundTrip(original), original)
    }

    func test_relationshipNote_codableRoundTrips() throws {
        let original = RelationshipNote(name: "Sam", relation: "spouse", notes: "likes coffee")
        XCTAssertEqual(try jsonRoundTrip(original), original)
    }

    func test_moodTransition_codableRoundTrips() throws {
        let original = MoodTransition(from: .idle, to: .delighted, why: "warm hello")
        XCTAssertEqual(try jsonRoundTrip(original), original)
    }
}
