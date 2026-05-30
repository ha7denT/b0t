import FoundationModels

/// The engine-neutral contract for a model's typed output.
///
/// It refines `Generable` so the Foundation Models engine can keep using the
/// macro path (`session.respond(generating:)`). It also requires `Codable` so
/// the Stage B llama.cpp engine can decode grammar-constrained JSON output to
/// the same type. The two paths produce the same Swift value; the engine
/// chooses how to populate it.
///
/// Stage B added two requirements for the llama path: `gbnfGrammar` (a
/// pre-generated GBNF grammar, committed under `Resources/Grammars/`, that
/// constrains llama.cpp output to this type's JSON shape) and `jsonShapeHint`
/// (a concise human-readable field description rendered into the prompt, since
/// llama.cpp does not inject the schema). `gbnfGrammar` has a default
/// implementation (loads the resource by type name); `jsonShapeHint` is
/// provided per type. See `StructuredOutput+Grammar.swift`.
public protocol StructuredOutput: Generable, Codable, Sendable {
    static var gbnfGrammar: String { get }
    static var jsonShapeHint: String { get }
}

extension ConversationResponse: StructuredOutput {}
extension TickDecision: StructuredOutput {}
extension MemoryObservation: StructuredOutput {}
extension RelationshipNote: StructuredOutput {}
extension MoodTransition: StructuredOutput {}
