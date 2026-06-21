import SwiftUI
import XCTest

@testable import b0tHome

@MainActor
final class ConfigurationPlaceholderViewTests: XCTestCase {
    func test_configurationPlaceholder_builds() {
        _ = ConfigurationPlaceholderView()
    }
}
