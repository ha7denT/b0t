import SwiftUI
import XCTest

@testable import b0tDesign

final class WundercogPaletteTests: XCTestCase {
    func test_shellOffwhite_isWarmOffwhite() {
        let color = WundercogPalette.shellOffwhite
        XCTAssertNotEqual(color, Color.clear)
        XCTAssertNotEqual(color, Color.black)
    }

    func test_allRoles_areDistinct() {
        let roles: [Color] = [
            WundercogPalette.shellOffwhite,
            WundercogPalette.accentMint,
            WundercogPalette.bezelMintThin,
            WundercogPalette.eyePhosphor,
            WundercogPalette.seamDark,
        ]
        let unique = Set(roles.map { String(describing: $0) })
        XCTAssertEqual(unique.count, roles.count, "palette roles collapsed to \(unique.count)")
    }
}
