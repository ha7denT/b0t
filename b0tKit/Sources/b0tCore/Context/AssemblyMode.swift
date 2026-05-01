import Foundation

/// What kind of assembled prompt the `ContextAssembler` should produce.
///
/// `.conversation` is a user-driven turn — the prompt body is the user's
/// message plus a snapshot of identity + memory + recent journal.
///
/// `.heartbeat` is a scheduled or event-triggered tick — the prompt body
/// includes the full text of `actions.md` (which drives per-beat behaviour)
/// plus the trigger context and any missed-beat gap.
///
/// `.fallback` is internal — used by `ContextAssembler`'s graduated overflow
/// recovery when the model returns `.exceededContextWindowSize`. Each level
/// drops more content (oldest journal entries → low-importance memory →
/// surface-the-overflow). See spec §7.4.
public enum AssemblyMode: Sendable {
    case conversation(userPrompt: String)
    case heartbeat(trigger: TickTrigger, missedGap: Duration?)
    case fallback(level: Int, base: BaseMode)

    public enum BaseMode: Sendable {
        case conversation(userPrompt: String)
        case heartbeat(trigger: TickTrigger, missedGap: Duration?)
    }
}
