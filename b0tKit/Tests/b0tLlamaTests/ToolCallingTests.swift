import XCTest

@testable import b0tLlama

/// Host unit tests for the pure (non-model) parts of the GBNF tool-call loop
/// (ADR-0018) and the Q6 fixtures/scoring. No llama model is loaded here; the
/// end-to-end generate path is covered by the gated live test.
final class ToolCallingTests: XCTestCase {

    // MARK: - JSONValue round-trip

    func test_jsonValue_roundTripsObject() throws {
        let original = JSONValue.object([
            "title": .string("call dentist"),
            "count": .number(3),
            "done": .bool(false),
            "tags": .array([.string("a"), .null]),
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Envelope decoding

    func test_envelope_decodesToolAndArguments() throws {
        let json = #"{"tool": "reminders.create", "arguments": {"title": "milk"}}"#
        let env = try JSONDecoder().decode(ToolCallEnvelope.self, from: Data(json.utf8))
        XCTAssertEqual(env.tool, "reminders.create")
        XCTAssertEqual(env.arguments.objectKeys, ["title"])
    }

    // MARK: - Grammar builder

    func test_grammar_containsRootToolNamesAndJSONRules() {
        let names = ["calendar.upcoming_events", "reminders.create"]
        let g = ToolCallGrammarBuilder.grammar(toolNames: names)
        XCTAssertTrue(g.contains("root ::="))
        // The JSON quotes are escaped in GBNF source: the grammar emits \"tool\".
        XCTAssertTrue(g.contains("\\\"tool\\\""))
        XCTAssertTrue(g.contains("\\\"arguments\\\""))
        // Each tool name appears as a quoted JSON string literal alternative.
        XCTAssertTrue(g.contains("\\\"calendar.upcoming_events\\\""))
        XCTAssertTrue(g.contains("\\\"reminders.create\\\""))
        // Standard JSON sub-rules present so `arguments` can be any object.
        for rule in ["object ::=", "array ::=", "string ::=", "number ::=", "space ::="] {
            XCTAssertTrue(g.contains(rule), "missing rule: \(rule)")
        }
    }

    func test_grammar_emptyNamesDoesNotProduceDanglingAlternation() {
        let g = ToolCallGrammarBuilder.grammar(toolNames: [])
        XCTAssertTrue(g.contains("toolname ::="))
        // Must not start the alternation rule with a stray " | ".
        XCTAssertFalse(g.contains("toolname ::=  |"))
    }

    // MARK: - Parsing (tolerant of surrounding prose)

    func test_parse_extractsEnvelopeFromPlainJSON() {
        let env = LlamaToolCallLoop.parse(
            #"{"tool": "time.now", "arguments": {}}"#)
        XCTAssertEqual(env?.tool, "time.now")
    }

    func test_parse_extractsEnvelopeDespiteSurroundingProse() {
        let raw = "Sure! Here you go:\n{\"tool\": \"reminders.list\", \"arguments\": {}}\nHope that helps."
        XCTAssertEqual(LlamaToolCallLoop.parse(raw)?.tool, "reminders.list")
    }

    func test_parse_returnsNilForNonEnvelopeJSON() {
        // Valid JSON object, but missing the required `tool`/`arguments` keys.
        XCTAssertNil(LlamaToolCallLoop.parse(#"{"foo": 1}"#))
        XCTAssertNil(LlamaToolCallLoop.parse("no json here at all"))
    }

    // MARK: - System prompt rendering

    func test_renderSystemPrompt_listsEveryToolNameAndDescription() {
        let prompt = LlamaToolCallLoop.renderSystemPrompt(tools: Q6ToolCallFixtures.descriptors)
        for d in Q6ToolCallFixtures.descriptors {
            XCTAssertTrue(prompt.contains(d.name), "prompt missing tool name \(d.name)")
            XCTAssertTrue(prompt.contains(d.description), "prompt missing desc for \(d.name)")
        }
        XCTAssertTrue(prompt.contains("ONLY a JSON object"))
    }

    // MARK: - Fixtures + scoring

    func test_fixtures_areNonEmptyAndReferenceKnownTools() {
        XCTAssertFalse(Q6ToolCallFixtures.probes.isEmpty)
        let known = Set(Q6ToolCallFixtures.descriptors.map(\.name))
        for probe in Q6ToolCallFixtures.probes {
            XCTAssertTrue(
                known.contains(probe.expectedTool),
                "probe expects unknown tool \(probe.expectedTool)")
        }
    }

    func test_score_countsParsedAndCorrect() {
        let results: [(probe: ToolCallProbe, call: ToolCallEnvelope?)] = [
            (
                .init(prompt: "a", expectedTool: "time.now"),
                .init(tool: "time.now", arguments: .object([:]))
            ),  // correct
            (
                .init(prompt: "b", expectedTool: "reminders.create"),
                .init(tool: "time.now", arguments: .object([:]))
            ),  // parsed, wrong tool
            (.init(prompt: "c", expectedTool: "reminders.list"), nil),  // unparsed
        ]
        let score = Q6ToolCallFixtures.score(results)
        XCTAssertEqual(score.total, 3)
        XCTAssertEqual(score.parsed, 2)
        XCTAssertEqual(score.correctTool, 1)
        XCTAssertEqual(score.hitRate, 1.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(score.parseRate, 2.0 / 3.0, accuracy: 1e-9)
    }
}
