import Foundation
import FoundationModels

/// The model's output for a heartbeat tick.
///
/// Maps directly to OpenClaw's six fields (observed/considered/decided/why/acted)
/// plus mood and organUsed. `state_delta` is NOT a field here — it's computed
/// by JournalWriter from Executor side effects (see spec §3 / §5.5).
///
/// `organUsed` is a skill identifier (e.g., "calendar", "mail") indicating which
/// b0t organ engaged this beat, or nil if no skill was involved. Phase 2 ships
/// only the time-awareness tool (Slice 9), so most ticks will have nil here.
@Generable
public struct TickDecision: Sendable, Equatable {
    @Guide(description: "What you noticed at this beat — one sentence.")
    public let observed: String

    @Guide(description: "The actions you considered taking, as labels.")
    public let considered: [String]

    @Guide(description: "Which action you chose — one of the considered labels.")
    public let decided: String

    @Guide(description: "Why you chose that action — one sentence.")
    public let why: String

    @Guide(description: "What you did in concrete terms (e.g., 'noted silently', 'posted to chat').")
    public let acted: String

    @Guide(description: "Your current mood, or nil if no meaningful change.")
    public let mood: MoodTag?

    @Guide(description: "The skill organ used this beat (e.g., 'calendar'), or nil.")
    public let organUsed: String?

    @Guide(description: "Things to remember from this beat.")
    public let memoryObservations: [MemoryObservation]

    public init(
        observed: String,
        considered: [String],
        decided: String,
        why: String,
        acted: String,
        mood: MoodTag? = nil,
        organUsed: String? = nil,
        memoryObservations: [MemoryObservation] = []
    ) {
        self.observed = observed
        self.considered = considered
        self.decided = decided
        self.why = why
        self.acted = acted
        self.mood = mood
        self.organUsed = organUsed
        self.memoryObservations = memoryObservations
    }
}
