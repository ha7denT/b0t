import Foundation
import FoundationModels

/// How significant a memory observation is.
///
/// `.medium` and `.high` are persisted to `memory/recent.md` by the
/// Executor (Task 12). `.low` is logged in DEBUG only; it represents
/// transient noticing that doesn't warrant a memory write.
@Generable
public enum Importance: String, Sendable, Equatable, CaseIterable {
    case low
    case medium
    case high
}
