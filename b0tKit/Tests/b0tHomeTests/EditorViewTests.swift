import XCTest

import b0tBrain

@testable import b0tHome

@MainActor
final class EditorViewTests: XCTestCase {
    func test_editor_savesEditedContentToDisk() async throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(component: "phase4-editor-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let testFile = tmp.appending(path: "test.md")
        try "---\nfoo: 1\n---\n\n# original\n".write(
            to: testFile, atomically: true, encoding: .utf8)

        let store = BotStore()
        let file = try await store.read(testFile)

        let editor = EditorView(file: file, store: store, onClose: {})
        await editor.save(rawContent: "---\nfoo: 2\n---\n\n# edited\n")

        let updated = try await store.read(testFile)
        XCTAssertTrue(updated.prose.contains("# edited"))

        try? FileManager.default.removeItem(at: tmp)
    }

    func test_editor_initialContentReflectsFileText() throws {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        let file = try BotFile(fileURL: url, text: "---\nfoo: 1\n---\n\n# original\n")
        let editor = EditorView(file: file, store: BotStore(), onClose: {})
        XCTAssertEqual(editor.initialRawContent, "---\nfoo: 1\n---\n\n# original\n")
    }
}
