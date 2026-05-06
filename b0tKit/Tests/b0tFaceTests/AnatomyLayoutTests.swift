import XCTest

@testable import b0tFace

final class AnatomyLayoutTests: XCTestCase {
    func test_layout_hasPositionForEveryOrgan() {
        for organ in OrganID.allCases {
            let pos = AnatomyLayout.position(for: organ, in: CGSize(width: 390, height: 480))
            XCTAssertNotNil(pos, "no position for \(organ)")
        }
    }

    func test_reasoning_isAtCrown() {
        let pos = AnatomyLayout.position(for: .reasoning, in: CGSize(width: 390, height: 480))
        XCTAssertEqual(pos.x, 0, accuracy: 1.0)
        XCTAssertGreaterThan(pos.y, 0, "reasoning should be above face centre")
    }

    func test_heart_isAtBottomCentre() {
        let pos = AnatomyLayout.position(for: .heart, in: CGSize(width: 390, height: 480))
        XCTAssertEqual(pos.x, 0, accuracy: 1.0)
        XCTAssertLessThan(pos.y, 0, "heart should be below face centre")
    }

    func test_aboveEyeLineOrgans_haveYPositiveOrAtCrown() {
        for organ in [OrganID.reasoning, .memory, .identity, .modules] {
            let pos = AnatomyLayout.position(for: organ, in: CGSize(width: 390, height: 480))
            XCTAssertGreaterThanOrEqual(pos.y, 0, "\(organ) should be at or above eye-line")
        }
    }

    func test_belowEyeLineOrgans_haveYNegative() {
        for organ in [OrganID.tools, .sensors, .location, .network] {
            let pos = AnatomyLayout.position(for: organ, in: CGSize(width: 390, height: 480))
            XCTAssertLessThan(pos.y, 0, "\(organ) should be below eye-line")
        }
    }

    func test_organBaseSize_is64() {
        XCTAssertEqual(AnatomyLayout.organSize, CGSize(width: 64, height: 64))
    }
}
