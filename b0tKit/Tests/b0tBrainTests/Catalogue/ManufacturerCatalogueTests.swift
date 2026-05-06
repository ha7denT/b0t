import XCTest

@testable import b0tBrain

final class ManufacturerCatalogueTests: XCTestCase {
    func test_loadFromBundle_findsHilfer() throws {
        let url = try fixtureURL()
        let catalogue = try ManufacturerCatalogue.load(from: url)
        XCTAssertEqual(catalogue.starterModel()?.id, "hilfer")
    }

    func test_starterModel_defaults_includeShippedModules() throws {
        let url = try fixtureURL()
        let catalogue = try ManufacturerCatalogue.load(from: url)
        let hilfer = catalogue.starterModel()
        XCTAssertTrue(hilfer?.defaultModules.contains("calendar") ?? false)
        XCTAssertTrue(hilfer?.defaultModules.contains("reminders") ?? false)
        XCTAssertTrue(hilfer?.defaultModules.contains("time-awareness") ?? false)
        XCTAssertTrue(hilfer?.defaultModules.contains("health") ?? false)
    }

    func test_catalogue_listsWundercogManufacturer() throws {
        let url = try fixtureURL()
        let catalogue = try ManufacturerCatalogue.load(from: url)
        XCTAssertEqual(catalogue.manufacturers.count, 1)
        XCTAssertEqual(catalogue.manufacturers.first?.id, "wundercog")
    }

    private func fixtureURL() throws -> URL {
        // Fixtures/ ships as .copy("Fixtures") in Package.swift, so the file
        // lands at <bundleResourceURL>/Fixtures/manufacturers.json. Bundle.module
        // doesn't auto-search subdirectories, so address it directly.
        guard let resourceURL = Bundle.module.resourceURL else {
            throw XCTSkip("Bundle.module has no resourceURL")
        }
        let url = resourceURL.appendingPathComponent("Fixtures/manufacturers.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("manufacturers.json fixture missing from b0tBrainTests bundle: \(url.path)")
        }
        return url
    }
}
