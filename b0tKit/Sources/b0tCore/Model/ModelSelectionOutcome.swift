/// Outcome of a model-selection request. `.missing` tells the UI to bounce to
/// the Directory tab and offer the download (spec §2 — "immediate re-resolve + load").
public enum ModelSelectionOutcome: Sendable, Equatable {
    case active(modelId: String)
    case missing(modelId: String)
}
