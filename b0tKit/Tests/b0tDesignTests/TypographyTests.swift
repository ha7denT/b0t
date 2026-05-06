import SwiftUI
import XCTest

@testable import b0tDesign

final class TypographyTests: XCTestCase {
    func test_systemMono_isIoskeleyMonoNL() {
        let font = Typography.systemMono(size: 14)
        _ = font  // smoke: constructed without trapping
        XCTAssertEqual(Typography.systemMonoFamily, "IoskeleyMonoNL-Regular")
    }

    func test_chatBody_isVerdana() {
        let font = Typography.chatBody(size: 15)
        _ = font
        XCTAssertEqual(Typography.chatBodyFamily, "Verdana")
    }
}
