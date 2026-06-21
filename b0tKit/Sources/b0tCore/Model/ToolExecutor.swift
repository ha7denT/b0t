import Foundation
import FoundationModels

/// Result of running a tool: human/model-readable summaries fed to the answer
/// pass and recorded in the `ToolCallRecord`.
public struct ToolRunResult: Sendable, Equatable {
    public let outputSummary: String
    public let argumentsSummary: String
    public init(outputSummary: String, argumentsSummary: String) {
        self.outputSummary = outputSummary
        self.argumentsSummary = argumentsSummary
    }
}

/// Executes an `any Tool` (FoundationModels `Tool`) from JSON arguments, for the
/// llama tool-call loop. Uses Swift implicit existential opening to recover the
/// concrete tool type, build its `@Generable` `Arguments` from `GeneratedContent`,
/// call it, and stringify the output. No per-tool code.
public enum ToolExecutor {
    public static func tool(named name: String, in tools: [any Tool]) -> (any Tool)? {
        tools.first { $0.name == name }
    }

    public static func execute(tool: any Tool, argumentsJSON: String) async throws -> ToolRunResult {
        try await run(tool, argumentsJSON: argumentsJSON)
    }

    private static func run<T: Tool>(_ tool: T, argumentsJSON: String) async throws -> ToolRunResult {
        let content = try GeneratedContent(json: argumentsJSON)
        let args = try T.Arguments(content)
        let output = try await tool.call(arguments: args)
        return ToolRunResult(outputSummary: stringify(output), argumentsSummary: argumentsJSON)
    }

    private static func stringify(_ value: Any) -> String {
        if let convertible = value as? any ConvertibleToGeneratedContent {
            return convertible.generatedContent.jsonString
        }
        return String(describing: value)
    }
}
