import XCTest

@testable import b0tLlama

final class LlamaToolGateTests: XCTestCase {
    let tools: [ToolDescriptor] = [
        .init(name: "time.now", description: "current time"),
        .init(name: "calendar.upcoming_events", description: "upcoming events"),
    ]

    func test_gateGrammar_includesNoneAndToolNames() {
        let g = ToolGate.grammar(for: tools)
        XCTAssertTrue(g.contains("time.now"))
        XCTAssertTrue(g.contains("calendar.upcoming_events"))
        XCTAssertTrue(g.contains("none"))
    }

    func test_gatePrompt_listsToolsAndAllowsNone() {
        let p = ToolGate.systemPrompt(for: tools)
        XCTAssertTrue(p.contains("time.now"))
        XCTAssertTrue(p.contains("none"))
    }

    func test_argumentsJSONString_serialisesEnvelopeArguments() throws {
        let env = ToolCallEnvelope(tool: "time.now", arguments: .object([:]))
        XCTAssertEqual(ToolGate.argumentsJSON(env), "{}")
    }

    func test_isNone_detectsTheReservedName() {
        XCTAssertTrue(ToolGate.isNone(ToolCallEnvelope(tool: "none", arguments: .object([:]))))
        XCTAssertFalse(ToolGate.isNone(ToolCallEnvelope(tool: "time.now", arguments: .object([:]))))
    }
}
