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

    func test_leftColumnOrgans_haveXNegative() {
        // Left column — world-facing I/O, per ADR-0017.
        for organ in [OrganID.network, .location, .sensors, .tools] {
            let pos = AnatomyLayout.position(for: organ, in: CGSize(width: 390, height: 480))
            XCTAssertLessThan(pos.x, 0, "\(organ) should be in the left column")
        }
    }

    func test_rightColumnOrgans_haveXPositive() {
        // Right column — inward / mind, per ADR-0017.
        for organ in [OrganID.memory, .identity, .modules, .journal] {
            let pos = AnatomyLayout.position(for: organ, in: CGSize(width: 390, height: 480))
            XCTAssertGreaterThan(pos.x, 0, "\(organ) should be in the right column")
        }
    }

    func test_processorAndHeart_areCentred() {
        let processor = AnatomyLayout.position(for: .reasoning, in: CGSize(width: 390, height: 480))
        let heart = AnatomyLayout.position(for: .heart, in: CGSize(width: 390, height: 480))
        XCTAssertEqual(processor.x, 0, accuracy: 1.0)
        XCTAssertEqual(heart.x, 0, accuracy: 1.0)
        XCTAssertGreaterThan(processor.y, 0, "processor crown above centre")
        XCTAssertLessThan(heart.y, 0, "heart below centre")
    }

    func test_organBaseSize_is64() {
        XCTAssertEqual(AnatomyLayout.organSize, CGSize(width: 64, height: 64))
    }
}
