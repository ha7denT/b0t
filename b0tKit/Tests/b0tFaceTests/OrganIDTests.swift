import XCTest

@testable import b0tFace

final class OrganIDTests: XCTestCase {
    func test_organID_hasTenCases() {
        XCTAssertEqual(OrganID.allCases.count, 10)
    }

    func test_organID_includesAllTenSubsystems() {
        let expected: Set<OrganID> = [
            .reasoning, .memory, .identity, .modules, .journal,
            .sensors, .tools, .network, .location,
            .heart,
        ]
        XCTAssertEqual(Set(OrganID.allCases), expected)
    }

    func test_organID_rawValuesMatchSceneNodeNames() {
        XCTAssertEqual(OrganID.heart.rawValue, "heart")
        XCTAssertEqual(OrganID.reasoning.rawValue, "reasoning")
        XCTAssertEqual(OrganID.modules.rawValue, "modules")
        XCTAssertEqual(OrganID.journal.rawValue, "journal")
    }
}
