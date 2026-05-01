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
/// Graduated overflow fallback (spec §7.4) is implemented internally to
/// `ContextAssembler` and is not exposed as a public mode. See Slice 10
/// Task 36 for that implementation.
public enum AssemblyMode: Sendable {
    case conversation(userPrompt: String)
    case heartbeat(trigger: TickTrigger, missedGap: Duration?)
}
