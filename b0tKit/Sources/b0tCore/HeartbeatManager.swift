import Foundation
import FoundationModels
import OSLog
import b0tBrain

/// Orchestrates one heartbeat tick: assemble context → call client → apply
/// executor → append journal entry.
///
/// Slice 5 (this file): manual-trigger path only. No BGAppRefreshTask, no
/// schedule.md interpretation, no missed-beat detection.
///
/// Slice 6 (Task 24-25): adds quiet-hours suppression and actions.md prose
/// injection. Slice 7 (Task 27): adds missed-beat detection. Slice 8 (Task 30-32):
/// adds register/scheduleNext/BGAppRefreshTask wiring + DEBUG timer fallback.
public actor HeartbeatManager {
    private let bot: Bot
    private let store: BotStore
    private let client: any LanguageModelClient
    private let clock: any Clock
    private let assembler: ContextAssembler
    private let executor: Executor
    private let journalWriter: JournalWriter

    private var nextBeatNumber: Int = 1
    private var didLoadBeatNumber: Bool = false

    private static let logger = Logger(
        subsystem: "com.toppeross.b0t.b0tCore", category: "HeartbeatManager")

    public init(
        bot: Bot,
        store: BotStore,
        client: any LanguageModelClient,
        clock: any Clock = SystemClock()
    ) {
        self.bot = bot
        self.store = store
        self.client = client
        self.clock = clock
        self.assembler = ContextAssembler(bot: bot, store: store)
        self.executor = Executor(bot: bot, store: store)
        self.journalWriter = JournalWriter(bot: bot, store: store, clock: clock)
    }

    public func tick(trigger: TickTrigger) async throws -> TickResult {
        if !didLoadBeatNumber {
            nextBeatNumber = await loadNextBeatNumber()
            didLoadBeatNumber = true
        }
        let beatNumber = nextBeatNumber
        nextBeatNumber += 1

        // Quiet-hours check.
        if let schedule = await loadSchedule(),
            schedule.isQuietHours(at: clock.now())
        {
            try? await journalWriter.appendSuppressed(
                reason: .quietHours, beatNumber: beatNumber
            )
            return .suppressed(reason: .quietHours)
        }

        do {
            let context = try await assembler.assemble(
                mode: .heartbeat(trigger: trigger, missedGap: nil)
            )
            let decision = try await client.generate(
                context: context,
                generating: TickDecision.self
            )
            let delta = try await executor.apply(decision)
            try await journalWriter.appendTick(
                decision: decision,
                stateDelta: delta,
                beatNumber: beatNumber
            )
            return .decided(decision)
        } catch LanguageModelClientError.modelUnavailable {
            try? await journalWriter.appendSuppressed(
                reason: .modelUnavailable,
                beatNumber: beatNumber
            )
            return .suppressed(reason: .modelUnavailable)
        } catch {
            Self.logger.error("heartbeat tick failed: \(String(describing: error))")
            return .errored(message: String(describing: error))
        }
    }

    private func loadSchedule() async -> HeartbeatSchedule? {
        do {
            let scheduleFile = try await bot.heartbeat.schedule
            return try HeartbeatSchedule.parse(scheduleFile)
        } catch {
            Self.logger.warning(
                "failed to parse schedule.md, falling back to defaults: \(String(describing: error))")
            return nil
        }
    }

    /// Reads today's journal file and returns the next beat number.
    /// Phase 2 simplification: scan for "— heartbeat N" headers (em-dash escape
    /// matches JournalWriter.appendTick's writer format byte-exactly), return
    /// max(N) + 1, or 1 if no journal yet.
    /// MUST stay byte-compatible with JournalWriter's "## HH:MM — heartbeat N" header.
    private func loadNextBeatNumber() async -> Int {
        let url = journalWriter.journalURL(for: clock.now())
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return 1 }
        let pattern = "\u{2014} heartbeat ([0-9]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 1 }
        let range = NSRange(content.startIndex..., in: content)
        var maxN = 0
        regex.enumerateMatches(in: content, range: range) { match, _, _ in
            guard let match,
                let nrange = Range(match.range(at: 1), in: content),
                let n = Int(content[nrange])
            else { return }
            if n > maxN { maxN = n }
        }
        return maxN + 1
    }
}
