import Foundation

/// A single-shot GBNF-constrained tool-call step on the pure-C llama path
/// (ADR-0018). Given a user prompt and a set of tool descriptors, it renders a
/// tool list into the prompt, generates under a tool-call grammar, and parses
/// the resulting envelope.
///
/// "Single-shot" = it picks a tool + arguments; it does NOT execute the tool or
/// feed results back. Execution + iteration need live `b0tModules` + permissions
/// and land with the real C3/C4 loop. The prompt-rendering and parsing here are
/// pure and unit-tested; the one `runtime.generate` call is exercised on-device
/// / in the gated live test.
public struct LlamaToolCallLoop {
    private let runtime: LlamaRuntime

    public init(runtime: LlamaRuntime) {
        self.runtime = runtime
    }

    /// Renders the system prompt that lists the available tools and instructs
    /// the model to emit a single tool-call envelope. Pure — unit-tested.
    public static func renderSystemPrompt(tools: [ToolDescriptor]) -> String {
        let list = tools.map { "- \($0.name): \($0.description)" }.joined(separator: "\n")
        return """
            You can call exactly one tool to help answer the user. Available tools:
            \(list)

            Respond with ONLY a JSON object of the form \
            {"tool": "<one of the tool names above>", "arguments": { ... }} \
            and nothing else. Choose the single most appropriate tool.
            """
    }

    /// Parses raw model output into a tool-call envelope, tolerating prose
    /// around the JSON (reuses `LlamaEngine.firstJSONObject`). Pure —
    /// unit-tested. Returns nil if no decodable envelope is present.
    public static func parse(_ raw: String) -> ToolCallEnvelope? {
        guard
            let json = LlamaEngine.firstJSONObject(in: raw),
            let data = json.data(using: .utf8),
            let envelope = try? JSONDecoder().decode(ToolCallEnvelope.self, from: data)
        else { return nil }
        return envelope
    }

    /// Picks a tool for `userPrompt`, constrained to `tools`. Returns nil if the
    /// model's output didn't parse into a valid envelope.
    public func pickTool(
        userPrompt: String,
        tools: [ToolDescriptor],
        maxTokens: Int = 256
    ) async throws -> ToolCallEnvelope? {
        let grammar = ToolCallGrammarBuilder.grammar(toolNames: tools.map(\.name))
        let messages = [
            LlamaChatMessage(role: "system", content: Self.renderSystemPrompt(tools: tools)),
            LlamaChatMessage(role: "user", content: userPrompt),
        ]
        let raw = try await runtime.generate(
            messages: messages, grammar: grammar, maxTokens: maxTokens)
        return Self.parse(raw)
    }
}
