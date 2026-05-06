import SwiftUI
import XCTest

@testable import b0tDesign

final class LCDPaletteTests: XCTestCase {
    func test_allRoles_areDistinct() {
        let roles: [Color] = [
            LCDPalette.bgWarm,
            LCDPalette.textAmber,
            LCDPalette.textDim,
            LCDPalette.chromeDark,
        ]
        let unique = Set(roles.map { String(describing: $0) })
        XCTAssertEqual(unique.count, roles.count)
    }

    func test_textDim_isDistinctFromTextAmber() {
        XCTAssertNotEqual(
            String(describing: LCDPalette.textAmber),
            String(describing: LCDPalette.textDim)
        )
    }
}
