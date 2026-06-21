import FoundationModels
import XCTest

@testable import b0tCore

/// Round-trips each @Generable type through the framework's GeneratedContent
/// serialization to catch macro misuse early.
final class GenerableRoundTripTests: XCTestCase {

    func test_conversationResponse_roundTrips() throws {
        let original = ConversationResponse(
            text: "hello",
            mood: .delighted,
            memoryObservations: [
                MemoryObservation(about: "Hayden", what: "likes coffee", importance: .medium)
            ]
        )
        let restored = try roundTrip(original)
        XCTAssertEqual(restored, original)
    }

    func test_tickDecision_roundTrips() throws {
        let original = TickDecision(
            observed: "afternoon",
            considered: ["pass", "glance_calendar"],
            decided: "pass",
            why: "nothing urgent",
            acted: "noted silently",
            mood: .attentive,
            organUsed: "calendar",
            memoryObservations: [
                MemoryObservation(about: "x", what: "y", importance: .low)
            ]
        )
        let restored = try roundTrip(original)
        XCTAssertEqual(restored, original)
    }

    func test_memoryObservation_roundTrips() throws {
        let original = MemoryObservation(about: "topic", what: "detail", importance: .high)
        let restored = try roundTrip(original)
        XCTAssertEqual(restored, original)
    }

    func test_relationshipNote_roundTrips() throws {
        let original = RelationshipNote(name: "Sam", relation: "spouse", notes: "likes coffee")
        let restored = try roundTrip(original)
        XCTAssertEqual(restored, original)
    }

    func test_moodTransition_roundTrips() throws {
        let original = MoodTransition(from: .idle, to: .delighted, why: "warm hello")
        let restored = try roundTrip(original)
        XCTAssertEqual(restored, original)
    }

    // MARK: - Private

    /// Serialises `value` to GeneratedContent via the macro-synthesised
    /// `ConvertibleToGeneratedContent` conformance, then reconstructs it via
    /// the macro-synthesised `ConvertibleFromGeneratedContent` initialiser.
    ///
    /// Uses `value.generatedContent` for the encode step (the property required
    /// by `ConvertibleToGeneratedContent`) and `T(raw)` for the decode step
    /// (`init(_ content: GeneratedContent)` from `ConvertibleFromGeneratedContent`).
    /// This is equivalent to the `GeneratedContent(value)` / `T(raw)` pair
    /// described in the spec — `GeneratedContent.init(_ value: some ConvertibleToGeneratedContent)`
    /// delegates to `value.generatedContent` internally.
    private func roundTrip<T: Generable & Equatable>(_ value: T) throws -> T {
        let raw = value.generatedContent
        return try T(raw)
    }
}
