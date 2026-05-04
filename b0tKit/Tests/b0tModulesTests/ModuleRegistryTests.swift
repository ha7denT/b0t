import XCTest
import b0tBrain
@testable import b0tModules

final class ModuleRegistryTests: XCTestCase {
    private func loadFixture(named name: String) async throws -> Bot {
        let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")!
        let store = BotStore()
        return try await store.load(at: url)
    }

    func testEmptyBotReturnsEmptyArray() async throws {
        let bot = try await loadFixture(named: "empty-modules-bot")
        let modules = try await ModuleRegistry.loadModules(for: bot)
        XCTAssertEqual(modules.count, 0)
    }

    func testMissingModuleIDThrows() async throws {
        let bot = try await loadFixture(named: "canonical-modules-bot")
        do {
            _ = try await ModuleRegistry.loadModules(for: bot)
            XCTFail("expected throw on missing module_id")
        } catch ModuleLoadError.missingModuleID {
            // expected — alphabetical iteration order means missing-id.md
            // throws before unknown.md skips. We accept this coupling.
        } catch {
            XCTFail("expected ModuleLoadError.missingModuleID, got \(error)")
        }
    }
}
