import FoundationModels
import XCTest

@testable import b0tCore

final class ToolExecutorTests: XCTestCase {
    @Generable struct EchoArgs: Equatable {
        @Guide(description: "text to echo") var text: String
    }
    @Generable struct EchoOut: Equatable {
        @Guide(description: "the echoed text") var echoed: String
    }
    struct EchoTool: Tool {
        let name = "echo"
        let description = "Echoes its text argument."
        func call(arguments: EchoArgs) async throws -> EchoOut { EchoOut(echoed: arguments.text) }
    }

    @Generable struct CountArgs: Equatable {
        @Guide(description: "how many") var n: Int
    }
    @Generable struct CountOut: Equatable {
        @Guide(description: "doubled") var doubled: Int
    }
    struct CountTool: Tool {
        let name = "count"
        let description = "Doubles n."
        func call(arguments: CountArgs) async throws -> CountOut { CountOut(doubled: arguments.n * 2) }
    }

    func test_execute_buildsArgsCallsToolAndStringifiesOutput() async throws {
        let tools: [any Tool] = [EchoTool()]
        let tool = try XCTUnwrap(ToolExecutor.tool(named: "echo", in: tools))
        let result = try await ToolExecutor.execute(tool: tool, argumentsJSON: #"{"text":"hi there"}"#)
        XCTAssertTrue(result.outputSummary.contains("hi there"))
        XCTAssertTrue(result.argumentsSummary.contains("hi there"))
    }

    func test_execute_intArgument_fromBareInteger() async throws {
        let tools: [any Tool] = [CountTool()]
        let tool = try XCTUnwrap(ToolExecutor.tool(named: "count", in: tools))
        let result = try await ToolExecutor.execute(tool: tool, argumentsJSON: #"{"n":24}"#)
        XCTAssertTrue(result.outputSummary.contains("48"))
    }

    func test_toolNamed_returnsNilForUnknown() {
        XCTAssertNil(ToolExecutor.tool(named: "nope", in: [EchoTool()]))
    }
}
