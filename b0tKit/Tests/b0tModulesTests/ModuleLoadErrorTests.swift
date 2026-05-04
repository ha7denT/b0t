import XCTest
@testable import b0tModules

final class ModuleLoadErrorTests: XCTestCase {
    func testMissingModuleIDCarriesFileURL() {
        let url = URL(fileURLWithPath: "/tmp/x.md")
        let error = ModuleLoadError.missingModuleID(file: url)
        if case .missingModuleID(let f) = error {
            XCTAssertEqual(f, url)
        } else {
            XCTFail("expected .missingModuleID")
        }
    }

    func testInvalidParametersCarriesIDAndUnderlying() {
        struct Underlying: Error, Equatable {}
        let error = ModuleLoadError.invalidParameters(moduleID: "calendar", underlying: Underlying())
        if case .invalidParameters(let id, let underlying) = error {
            XCTAssertEqual(id, "calendar")
            XCTAssertNotNil(underlying)
        } else {
            XCTFail("expected .invalidParameters")
        }
    }
}
