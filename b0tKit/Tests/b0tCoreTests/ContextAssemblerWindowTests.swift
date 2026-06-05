import XCTest
import b0tBrain

@testable import b0tCore

final class ContextAssemblerWindowTests: XCTestCase {
    func test_limit_followsProvider_acrossAssemblies() async throws {
        let fixturesURL = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/canonical-bot")
        let store = BotStore()
        let bot = try await store.load(at: fixturesURL)
        let windowBox = LockedWindowBox(4096)
        let assembler = ContextAssembler(
            bot: bot, store: BotStore(), tools: [], toolsRequirePermission: false,
            contextWindowProvider: { windowBox.value })

        let first = try await assembler.assemble(mode: .conversation(userPrompt: "hi"))
        XCTAssertEqual(first.budget.limit, 4096 - ContextAssembler.responseReserve)

        windowBox.value = 32768
        let second = try await assembler.assemble(mode: .conversation(userPrompt: "hi"))
        XCTAssertEqual(second.budget.limit, 32768 - ContextAssembler.responseReserve)
    }
}

/// Test-only mutable box (the production provider reads `EngineHost.contextWindow`).
final class LockedWindowBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Int
    init(_ v: Int) { _value = v }
    var value: Int {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); _value = newValue; lock.unlock() }
    }
}
