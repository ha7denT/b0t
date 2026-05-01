import FoundationModels
import XCTest
@testable import b0tCore

final class StubLanguageModelClientTests: XCTestCase {
    func test_returnsCannedConversationResponse() async throws {
        let stub = StubLanguageModelClient { context, outputType in
            XCTAssertEqual(context.userPrompt, "hi")
            XCTAssert(outputType == ConversationResponse.self)
            return ConversationResponse(text: "echo: hi")
        }
        let context = AssembledContext(userPrompt: "hi")
        let response: ConversationResponse = try await stub.generate(
            context: context,
            generating: ConversationResponse.self
        )
        XCTAssertEqual(response.text, "echo: hi")
    }

    func test_throwsWhenHandlerReturnsWrongType() async {
        // Stub's handler returns a String when the test asks for ConversationResponse.
        // The stub must surface this as malformedGenerableOutput rather than crash.
        let stub = StubLanguageModelClient { _, _ in
            // Return a String — wrong type relative to the request below.
            return "not a ConversationResponse" as Any
        }
        do {
            let _: ConversationResponse = try await stub.generate(
                context: AssembledContext(userPrompt: ""),
                generating: ConversationResponse.self
            )
            XCTFail("expected throw")
        } catch LanguageModelClientError.malformedGenerableOutput {
            // pass
        } catch {
            XCTFail("expected malformedGenerableOutput, got \(error)")
        }
    }

    func test_throwsConfiguredError() async {
        struct Boom: Error {}
        let stub = StubLanguageModelClient { _, _ in throw Boom() }
        do {
            let _: ConversationResponse = try await stub.generate(
                context: AssembledContext(userPrompt: ""),
                generating: ConversationResponse.self
            )
            XCTFail("expected throw")
        } catch is Boom {
            // pass — stub does not wrap; tests see the underlying error
        } catch {
            XCTFail("expected Boom, got \(error)")
        }
    }
}
