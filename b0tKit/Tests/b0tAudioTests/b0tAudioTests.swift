import XCTest
@testable import b0tAudio

final class b0tAudioTests: XCTestCase {
    func test_modulePlaceholder_identifierMatchesModuleName() {
        XCTAssertEqual(b0tAudioPlaceholder.identifier, "b0tAudio")
    }
}
