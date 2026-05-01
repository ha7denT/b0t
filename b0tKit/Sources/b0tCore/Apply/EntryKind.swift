import Foundation

/// Discriminator for which kind of journal entry a write is producing.
///
/// Used by `JournalWriter.appendError(error:kind:)` (Slice 10) so a single
/// error path serves both conversation turns and heartbeat ticks. The
/// `appendConversationTurn` and `appendTick` methods don't take this enum
/// because they're already kind-specific.
public enum EntryKind: Sendable, Equatable {
    case turn(number: Int)
    case heartbeat(number: Int)
}
