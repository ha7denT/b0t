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

    func test_execute_buildsArgsCallsToolAndStringifiesOutput() async throws {
        let tools: [any Tool] = [EchoTool()]
        let tool = try XCTUnwrap(ToolExecutor.tool(named: "echo", in: tools))
        let result = try await ToolExecutor.execute(tool: tool, argumentsJSON: #"{"text":"hi there"}"#)
        XCTAssertTrue(result.outputSummary.contains("hi there"))
        XCTAssertTrue(result.argumentsSummary.contains("hi there"))
    }

    func test_toolNamed_returnsNilForUnknown() {
        XCTAssertNil(ToolExecutor.tool(named: "nope", in: [EchoTool()]))
    }
}
