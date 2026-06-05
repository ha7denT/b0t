import Foundation
import b0tBrain
import b0tCore

/// `InferenceEngine` backed by a local GGUF model via `LlamaRuntime`.
///
/// When `supportsToolLoop` is `true` and the context carries tools, `generate`
/// runs a two-pass loop: (1) gate pass — pick a tool or "none" under the GBNF
/// gate grammar via `ToolGate`; (2) execute the chosen tool via `b0tCore`
/// `ToolExecutor` and inject the result; (3) answer pass — structured output
/// under the type's GBNF grammar. Without tools or with `supportsToolLoop`
/// `false`, a single structured-output pass is used.
public struct LlamaEngine: InferenceEngine {
    private let runtime: any LlamaGenerating
    private let supportsToolLoop: Bool

    public var contextWindow: Int { runtime.contextWindow }

    public init(modelPath: URL, contextLength: Int, supportsToolLoop: Bool = false) throws {
        self.runtime = try LlamaRuntime(modelPath: modelPath, contextLength: contextLength)
        self.supportsToolLoop = supportsToolLoop
    }

    /// Wraps an already-loaded `LlamaGenerating` instead of loading the model
    /// again. Lets callers share one resident model across the structured-output
    /// path and other runtime uses (e.g. the Q6 harness reusing its loaded
    /// model for both the GBNF and tool-call checks).
    public init(runtimeReusing runtime: any LlamaGenerating, supportsToolLoop: Bool = false) {
        self.runtime = runtime
        self.supportsToolLoop = supportsToolLoop
    }

    public func generate<Output: StructuredOutput>(
        context: AssembledContext,
        generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord]) {
        guard supportsToolLoop, !context.tools.isEmpty else {
            let output = try await singlePassStructured(context: context, generating: outputType)
            return (output, [])
        }

        // Pass 1 — tool gate: pick a tool (or "none") under the gate grammar.
        let descriptors = context.tools.map {
            ToolDescriptor(name: $0.name, description: $0.description)
        }
        let gateMessages = [
            LlamaChatMessage(role: "system", content: ToolGate.systemPrompt(for: descriptors)),
            LlamaChatMessage(role: "user", content: context.userPrompt),
        ]
        let gateRaw = try await runtime.generate(
            messages: gateMessages, grammar: ToolGate.grammar(for: descriptors), maxTokens: 256)

        var records: [ToolCallRecord] = []
        var answerContext = context

        if let env = LlamaToolCallLoop.parse(gateRaw), !ToolGate.isNone(env),
            let tool = ToolExecutor.tool(named: env.tool, in: context.tools)
        {
            let argsJSON = ToolGate.argumentsJSON(env)
            do {
                let result = try await ToolExecutor.execute(tool: tool, argumentsJSON: argsJSON)
                records.append(
                    ToolCallRecord(
                        toolName: env.tool, argumentsSummary: result.argumentsSummary,
                        outputSummary: result.outputSummary, timestamp: Date()))
                answerContext = Self.injectingToolResult(
                    context, tool: env.tool, summary: result.outputSummary)
            } catch {
                records.append(
                    ToolCallRecord(
                        toolName: env.tool, argumentsSummary: argsJSON,
                        outputSummary: "errored", timestamp: Date()))
                answerContext = Self.injectingToolResult(
                    context, tool: env.tool, summary: "(tool error: \(error))")
            }
        }
        // unparseable / unknown tool / "none" → answerContext unchanged, records empty

        // Pass 2 — final structured answer.
        let output = try await singlePassStructured(context: answerContext, generating: outputType)
        return (output, records)
    }

    /// Returns a copy of `context` with the tool result appended to the user
    /// prompt, so the answer pass can ground its reply on it.
    private static func injectingToolResult(
        _ context: AssembledContext, tool: String, summary: String
    ) -> AssembledContext {
        AssembledContext(
            systemInstructions: context.systemInstructions,
            userPrompt: context.userPrompt + "\n\ntool \(tool) result: \(summary)",
            tools: context.tools,
            toolsRequirePermission: context.toolsRequirePermission,
            budget: context.budget,
            loadedFiles: context.loadedFiles)
    }

    /// The final-answer / no-tools path: describe the shape in-prompt, generate
    /// under the type's GBNF grammar, decode JSON. (Factored out of the original
    /// `generate` body, unchanged.)
    private func singlePassStructured<Output: StructuredOutput>(
        context: AssembledContext,
        generating outputType: Output.Type
    ) async throws -> Output {
        // llama.cpp does not inject the schema, so describe the shape in-prompt.
        let userContent = """
            \(context.userPrompt)

            Respond with ONLY a JSON object and nothing else. \(Output.jsonShapeHint)
            """
        let messages = [
            LlamaChatMessage(role: "system", content: context.systemInstructions),
            LlamaChatMessage(role: "user", content: userContent),
        ]
        let raw = try await runtime.generate(
            messages: messages,
            grammar: Output.gbnfGrammar.isEmpty ? nil : Output.gbnfGrammar,
            maxTokens: 512
        )
        guard let data = Self.firstJSONObject(in: raw)?.data(using: .utf8) else {
            throw InferenceEngineError.malformedGenerableOutput(
                underlyingDescription: "no JSON object in llama output: \(raw.prefix(200))")
        }
        do {
            let value = try JSONDecoder().decode(Output.self, from: data)
            return value
        } catch {
            throw InferenceEngineError.malformedGenerableOutput(
                underlyingDescription: String(describing: error))
        }
    }

    /// Extracts the first balanced `{...}` span — defensive against models that
    /// wrap JSON in prose despite the grammar (and against grammar-off fallback).
    static func firstJSONObject(in text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var idx = start
        while idx < text.endIndex {
            let c = text[idx]
            if c == "{" { depth += 1 }
            if c == "}" {
                depth -= 1
                if depth == 0 { return String(text[start...idx]) }
            }
            idx = text.index(after: idx)
        }
        return nil
    }
}
