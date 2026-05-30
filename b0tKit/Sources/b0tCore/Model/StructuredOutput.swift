import FoundationModels

/// The engine-neutral contract for a model's typed output.
///
/// It refines `Generable` so the Foundation Models engine can keep using the
/// macro path (`session.respond(generating:)`). It also requires `Codable` so
/// the Stage B llama.cpp engine can decode grammar-constrained JSON output to
/// the same type. The two paths produce the same Swift value; the engine
/// chooses how to populate it.
///
/// Stage B adds a `static var jsonSchema` requirement here (used to derive a
/// GBNF grammar and a prompt-side description); it is intentionally absent now
/// so we don't author schemas ahead of the engine that consumes them.
public protocol StructuredOutput: Generable, Codable, Sendable {}

extension ConversationResponse: StructuredOutput {}
extension TickDecision: StructuredOutput {}
extension MemoryObservation: StructuredOutput {}
extension RelationshipNote: StructuredOutput {}
extension MoodTransition: StructuredOutput {}
