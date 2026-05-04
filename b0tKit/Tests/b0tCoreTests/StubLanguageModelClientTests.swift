import FoundationModels
import XCTest
import b0tBrain

@testable import b0tCore

final class StubLanguageModelClientTests: XCTestCase {
    func testReturnsTypedOutputAndEmptyRecords() async throws {
        let client = StubLanguageModelClient { context, type in
            return ConversationResponse(
                text: "echo: \(context.userPrompt)", mood: .thinking, memoryObservations: [])
        }
        let context = AssembledContext.testFixture(userPrompt: "hi")
        let (response, records) = try await client.generate(
            context: context, generating: ConversationResponse.self
        )
        XCTAssertEqual(response.text, "echo: hi")
        XCTAssertEqual(records.count, 0)
    }

    func testHandlerCanReturnTupleWithRecords() async throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let client = StubLanguageModelClient { context, type in
            return StubLanguageModelClient.HandlerResult(
                value: ConversationResponse(text: "done", mood: .thinking, memoryObservations: []),
                toolCalls: [
                    ToolCallRecord(
                        toolName: "time_awareness",
                        argumentsSummary: "(no args)",
                        outputSummary: "12:00 UTC, afternoon",
                        timestamp: date
                    )
                ]
            )
        }
        let context = AssembledContext.testFixture(userPrompt: "what time")
        let (response, records) = try await client.generate(
            context: context, generating: ConversationResponse.self
        )
        XCTAssertEqual(response.text, "done")
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].toolName, "time_awareness")
    }

    func testTypeMismatchStillReportsMalformed() async {
        let client = StubLanguageModelClient { _, _ in
            return "not a ConversationResponse"
        }
        let context = AssembledContext.testFixture(userPrompt: "x")
        do {
            _ = try await client.generate(context: context, generating: ConversationResponse.self)
            XCTFail("expected throw")
        } catch LanguageModelClientError.malformedGenerableOutput {
            // expected
        } catch {
            XCTFail("got \(error)")
        }
    }

    func testHandlerThrowingPropagates() async {
        struct Boom: Error {}
        let client = StubLanguageModelClient { _, _ in throw Boom() }
        let context = AssembledContext.testFixture(userPrompt: "x")
        do {
            _ = try await client.generate(context: context, generating: ConversationResponse.self)
            XCTFail("expected throw")
        } catch is Boom {
            // expected
        } catch {
            XCTFail("got unexpected error: \(error)")
        }
    }
}
