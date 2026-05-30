import Foundation

extension StructuredOutput {
    /// Loads the committed GBNF grammar named `<name>.gbnf` from the package's
    /// resource bundle. The source files live under `Resources/Grammars/`, but
    /// SwiftPM's `.process` rule flattens that directory into the bundle root,
    /// so the lookup is by base name (no subdirectory). Returns an empty string
    /// if absent so the llama engine can fall back to grammar-off generation.
    public static func loadGrammar(_ name: String) -> String {
        guard
            let url = Bundle.module.url(forResource: name, withExtension: "gbnf"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return text
    }
}

extension StructuredOutput {
    /// GBNF grammar (root rule "root") constraining llama.cpp output to this
    /// type's JSON shape. Pre-generated offline from the committed schema —
    /// the xcframework does not expose `json_schema_to_grammar`. Regenerate when
    /// the type's fields change (see `Resources/Grammars/*.schema.json`).
    public static var gbnfGrammar: String { Self.loadGrammar(String(describing: Self.self)) }
}

// Per-type prompt shape hints (rendered into the prompt; llama.cpp does not
// inject the schema). Concise, human-readable field descriptions.

extension ConversationResponse {
    public static var jsonShapeHint: String {
        "JSON object: text (string), mood (one of idle|speaking|thinking|surprised|sleepy|attentive|worried|delighted, or omit), memoryObservations (array of {about, what, importance: low|medium|high})."
    }
}

extension TickDecision {
    public static var jsonShapeHint: String {
        "JSON object: observed (string), considered (array of strings), decided (string), why (string), acted (string), mood (optional mood label), organUsed (optional string), memoryObservations (array of {about, what, importance})."
    }
}

extension MemoryObservation {
    public static var jsonShapeHint: String {
        "JSON object: about (string), what (string), importance (low|medium|high)."
    }
}

extension RelationshipNote {
    public static var jsonShapeHint: String {
        "JSON object: name (string), relation (string), notes (string)."
    }
}

extension MoodTransition {
    public static var jsonShapeHint: String {
        "JSON object: from (mood label), to (mood label), why (string)."
    }
}
