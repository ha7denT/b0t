import XCTest

import b0tBrain
import b0tFace

@testable import b0tHome

@MainActor
final class DirectoryNavigatorViewTests: XCTestCase {
    func test_navigator_listsFilesInDirectory() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(component: "phase4-nav-test-\(UUID().uuidString)")
        let dir = tmp.appending(path: "modules")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "---\nmodule_id: a\nenabled: true\n---\n".write(
            to: dir.appending(path: "a.md"), atomically: true, encoding: .utf8)
        try "---\nmodule_id: b\nenabled: false\n---\n".write(
            to: dir.appending(path: "b.md"), atomically: true, encoding: .utf8)

        let bot = Bot.empty(at: tmp)
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        let view = DirectoryNavigatorView(
            state: state, organ: .modules, directoryRelativePath: "modules")
        let entries = view.entries()
        XCTAssertEqual(Set(entries.map(\.name)), ["a.md", "b.md"])

        // Cleanup
        try? FileManager.default.removeItem(at: tmp)
    }
}
