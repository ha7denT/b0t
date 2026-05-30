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
}
