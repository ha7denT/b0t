import XCTest

@testable import b0tFace

final class OrganIDTests: XCTestCase {
    func test_organID_hasNineCases() {
        XCTAssertEqual(OrganID.allCases.count, 9)
    }

    func test_organID_includesAllNineSubsystems() {
        let expected: Set<OrganID> = [
            .reasoning, .memory, .identity, .modules,
            .sensors, .tools, .network, .location,
            .heart,
        ]
        XCTAssertEqual(Set(OrganID.allCases), expected)
    }

    func test_organID_rawValuesMatchSceneNodeNames() {
        XCTAssertEqual(OrganID.heart.rawValue, "heart")
        XCTAssertEqual(OrganID.reasoning.rawValue, "reasoning")
        XCTAssertEqual(OrganID.modules.rawValue, "modules")
    }
}
