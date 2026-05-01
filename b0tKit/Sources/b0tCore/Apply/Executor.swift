import Foundation
import OSLog
import b0tBrain

/// Applies a model decision to the bot's on-disk state.
///
/// Slice 3 (this file): writes high/medium-importance memory observations
/// to `memory/recent.md` (newest-first) and returns a StateDelta listing
/// the files written.
///
/// Slice 5 (Task 21) adds `apply(_ decision: TickDecision)` for heartbeat
/// ticks — same observation logic, plus optional `wouldNotifyText` capture.
///
/// Slice 6 (Task 26) adds notification budget enforcement.
///
/// Per spec §5.6, the Executor never posts real notifications in Phase 2.
public struct Executor: Sendable {
    private let bot: Bot
    private let store: BotStore

    private static let logger = Logger(
        subsystem: "com.toppeross.b0t.b0tCore", category: "Executor")

    public init(bot: Bot, store: BotStore) {
        self.bot = bot
        self.store = store
    }

    public func apply(_ response: ConversationResponse) async throws -> StateDelta {
        let persistable = response.memoryObservations.filter { $0.importance != .low }

        // Log .low observations in DEBUG without persisting.
        for observation in response.memoryObservations where observation.importance == .low {
            Self.logger.debug(
                "memory observation (low, not persisted): \(observation.about) — \(observation.what)"
            )
        }

        guard !persistable.isEmpty else {
            return .empty
        }

        let recentURL = bot.memory.recentURL
        let existing = try await bot.memory.recent
        let newProse = prependObservations(persistable, to: existing.prose)
        let updated = existing.replacingProse(with: newProse)
        try await store.write(updated)

        return StateDelta(writtenFiles: [recentURL])
    }

    private func prependObservations(
        _ observations: [MemoryObservation], to existing: String
    ) -> String {
        // Each observation becomes a markdown bullet stamped with its importance.
        // Newest-first: prepend the new lines above any existing content, separated by a blank line.
        let block = observations.map { obs in
            "- (\(obs.importance.rawValue)) \(obs.about): \(obs.what)"
        }.joined(separator: "\n")

        if existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return block + "\n"
        }
        return block + "\n\n" + existing
    }
}
