import Foundation
import XCTest

@testable import b0tBrain

final class BotEmptyTests: XCTestCase {
    func test_empty_returnsBotAtURL() {
        let url = URL(fileURLWithPath: "/tmp/b0t-empty-test")
        let bot = Bot.empty(at: url)
        XCTAssertEqual(bot.rootURL, url)
    }

    func test_empty_doesNotRequireDirectoryToExist() {
        // The factory is for tests/views that hold a Bot reference without doing I/O.
        let url = URL(fileURLWithPath: "/var/empty/never-exists-\(UUID().uuidString)")
        let bot = Bot.empty(at: url)
        XCTAssertEqual(bot.rootURL.path, url.path)
    }
}
