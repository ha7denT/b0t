import Foundation
import FoundationModels

/// A "remember this" payload the model can attach to any decision.
///
/// `about` is what the observation is about (a person, a project, a topic).
/// `what` is the observation itself. `importance` controls whether the
/// Executor persists it (medium/high → `memory/recent.md`) or just logs it.
@Generable
public struct MemoryObservation: Sendable, Equatable {
    @Guide(description: "Who or what the observation is about — a person's name, a project name, or a topic.")
    public let about: String

    @Guide(description: "The observation itself, as a single short sentence.")
    public let what: String

    @Guide(
        description:
            "How significant this observation is. low: transient, won't be persisted. medium: noteworthy. high: important — must be remembered."
    )
    public let importance: Importance

    public init(about: String, what: String, importance: Importance) {
        self.about = about
        self.what = what
        self.importance = importance
    }
}
