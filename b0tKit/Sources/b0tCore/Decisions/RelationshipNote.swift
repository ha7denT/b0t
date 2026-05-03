import Foundation
import FoundationModels

/// A note about a person the b0t has learned about.
///
/// Defined in Phase 2 (spec §6) but not exercised end-to-end. Phase 5's
/// onboarding sequence is the first consumer — it will branch in `Executor`
/// to write relationships into `memory/relationships.md`.
@Generable
public struct RelationshipNote: Sendable, Equatable {
    @Guide(description: "The person's name as the user refers to them.")
    public let name: String

    @Guide(description: "Their relation to the user (e.g., 'spouse', 'client at MPC').")
    public let relation: String

    @Guide(description: "Free-form notes about the person.")
    public let notes: String

    public init(name: String, relation: String, notes: String) {
        self.name = name
        self.relation = relation
        self.notes = notes
    }
}
