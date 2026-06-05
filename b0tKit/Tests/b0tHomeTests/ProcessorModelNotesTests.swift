import XCTest
import b0tBrain

@testable import b0tHome

final class ProcessorModelNotesTests: XCTestCase {
    func test_notes_includeLicenseDisclosureContextAndSource() {
        let notes = ProcessorModelNotes.markdown(for: InferenceModelCatalogue.qwen3)
        XCTAssertTrue(notes.contains("Qwen3 1.7B"))
        XCTAssertTrue(notes.contains("Apache-2.0"))
        XCTAssertTrue(notes.contains("32768"))
        XCTAssertTrue(notes.contains("bartowski/Qwen_Qwen3-1.7B-GGUF"))
        XCTAssertTrue(notes.contains(InferenceModelCatalogue.qwen3.disclosure))
    }

    func test_notes_fmEntry_omitsDownloadSource() {
        let notes = ProcessorModelNotes.markdown(for: InferenceModelCatalogue.foundationModelsDefault)
        XCTAssertTrue(notes.contains("Apple Foundation Models"))
        XCTAssertFalse(notes.contains("resolve/"))
    }
}
