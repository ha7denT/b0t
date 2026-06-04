import Foundation

/// Builds a GBNF grammar that constrains llama.cpp output to a tool-call
/// envelope: `{"tool": <one of the given names>, "arguments": <JSON object>}`.
///
/// The `tool` field is restricted to the supplied names (so the model can only
/// name a real tool); `arguments` is any well-formed JSON object. This is the
/// "format is the grammar's job" half of ADR-0018 — a successful parse is, by
/// construction, a well-formed call naming a known tool.
public enum ToolCallGrammarBuilder {
    /// Returns a GBNF grammar (root rule `root`) for the given tool names.
    /// Names are emitted as JSON string literals; an empty list yields a grammar
    /// that matches no tool (callers should pass at least one).
    public static func grammar(toolNames: [String]) -> String {
        // Each name becomes a quoted JSON string literal alternative, e.g.
        // the rule text `"\"calendar.upcoming_events\""`.
        let alternatives =
            toolNames
            .map { "\"\\\"\($0)\\\"\"" }
            .joined(separator: " | ")
        let toolRule = alternatives.isEmpty ? "\"\\\"\\\"\"" : alternatives

        return """
            root ::= "{" space "\\"tool\\"" space ":" space toolname space "," space "\\"arguments\\"" space ":" space object space "}" space
            toolname ::= \(toolRule) space
            value ::= object | array | string | number | "true" | "false" | "null"
            object ::= "{" space ( member ( "," space member )* )? "}" space
            member ::= string space ":" space value
            array ::= "[" space ( value ( "," space value )* )? "]" space
            string ::= "\\"" char* "\\"" space
            char ::= [^"\\\\\\x7F\\x00-\\x1F] | [\\\\] (["\\\\bfnrt] | "u" [0-9a-fA-F]{4})
            number ::= "-"? ("0" | [1-9] [0-9]*) ("." [0-9]+)? ([eE] [-+]? [0-9]+)? space
            space ::= | " " | "\\n"
            """
    }
}
