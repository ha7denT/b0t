import Foundation
import FoundationModels
import OSLog
import b0tBrain

/// Orchestrates one heartbeat tick: assemble context → call client → apply
/// executor → append journal entry. Also schedules the next BG task wake.
///
/// Slice 5 (this file): manual-trigger path only. No BGAppRefreshTask, no
/// schedule.md interpretation, no missed-beat detection.
///
/// Slice 6 (Task 24-25): adds quiet-hours suppression and actions.md prose
/// injection. Slice 7 (Task 27): adds missed-beat detection. Slice 8 (this commit
/// Task 29; Task 30-32) adds scheduleNext + register/BGAppRefreshTask wiring +
/// DEBUG timer fallback.
public actor HeartbeatManager {
    private let bot: Bot
    private let store: BotStore
    private let client: any LanguageModelClient
    private let clock: any Clock
    private let assembler: ContextAssembler
    private let executor: Executor
    private let journalWriter: JournalWriter
    private let missedBeatDetector: MissedBeatDetector
    private let scheduler: any HeartbeatScheduler

    private var nextBeatNumber: Int = 1
    private var didLoadBeatNumber: Bool = false

    private static let logger = Logger(
        subsystem: "com.toppeross.b0t.b0tCore", category: "HeartbeatManager")

    public init(
        bot: Bot,
        store: BotStore,
        client: any LanguageModelClient,
        clock: any Clock = SystemClock(),
        scheduler: any HeartbeatScheduler = LiveBGTaskScheduler()
    ) {
        self.bot = bot
        self.store = store
        self.client = client
        self.clock = clock
        self.scheduler = scheduler
        self.assembler = ContextAssembler(bot: bot, store: store)
        self.executor = Executor(bot: bot, store: store)
        self.journalWriter = JournalWriter(bot: bot, store: store, clock: clock)
        self.missedBeatDetector = MissedBeatDetector(bot: bot, store: store)
    }

    public func tick(trigger: TickTrigger) async throws -> TickResult {
        if !didLoadBeatNumber {
            nextBeatNumber = await loadNextBeatNumber()
            didLoadBeatNumber = true
        }
        let beatNumber = nextBeatNumber
        nextBeatNumber += 1

        let schedule = await loadSchedule()

        // Quiet-hours check.
        if let schedule, schedule.isQuietHours(at: clock.now()) {
            try? await journalWriter.appendSuppressed(
                reason: .quietHours, beatNumber: beatNumber
            )
            return .suppressed(reason: .quietHours)
        }

        // Compute missed-beat gap, if relevant.
        var missedGap: Duration? = nil
        if let schedule, let bpmInterval = schedule.bpmInterval,
            let actualGap = try? await missedBeatDetector.gap(now: clock.now())
        {
            // Threshold: 1.5x the expected interval.
            let threshold = bpmInterval * 3 / 2
            if actualGap > threshold {
                missedGap = actualGap
            }
        }

        do {
            let context = try await assembler.assemble(
                mode: .heartbeat(trigger: trigger, missedGap: missedGap)
            )
            let (decision, toolCalls) = try await client.generate(
                context: context,
                generating: TickDecision.self
            )
            let delta = try await executor.apply(decision)
            try await journalWriter.appendTick(
                decision: decision,
                stateDelta: delta,
                beatNumber: beatNumber,
                toolCalls: toolCalls
            )
            return .decided(decision: decision, delta: delta, toolCalls: toolCalls)
        } catch LanguageModelClientError.modelUnavailable {
            try? await journalWriter.appendSuppressed(
                reason: .modelUnavailable,
                beatNumber: beatNumber
            )
            return .suppressed(reason: .modelUnavailable)
        } catch {
            Self.logger.error("heartbeat tick failed: \(String(describing: error))")
            try? await journalWriter.appendError(error: error, kind: .heartbeat(number: beatNumber))
            return .errored(message: String(describing: error))
        }
    }

    /// Submits the next BG task request based on the schedule's BPM.
    /// No-op when bpm is 0 (scheduled beats off; event triggers still fire).
    public func scheduleNext() async throws {
        guard let schedule = await loadSchedule(),
            let interval = schedule.bpmInterval
        else {
            Self.logger.debug("scheduleNext skipped: no schedule or bpm is 0")
            return
        }
        let next = clock.now().addingTimeInterval(interval.timeInterval)
        try await scheduler.submitNextRequest(earliestBeginDate: next)
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

    #if DEBUG
        private var debugTimerTask: Task<Void, Never>? = nil

        /// Starts a DEBUG-only timer that fires `tick(.scheduled)` every `bpm/4` minutes.
        ///
        /// Activated via the `--debug-heartbeat-timer` launch arg. Only used in
        /// simulator development where BGAppRefreshTask is unreliable. The faster
        /// cadence (1/4 of the configured BPM) lets developers see the heartbeat
        /// path exercise in seconds rather than waiting full BPM intervals.
        public func startDebugTimer() {
            guard debugTimerTask == nil else { return }
            debugTimerTask = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self else { return }
                    let interval = await self.debugTimerInterval()
                    do {
                        try await Task.sleep(for: interval)
                    } catch {
                        return
                    }
                    _ = try? await self.tick(trigger: .scheduled)
                }
            }
        }

        public func stopDebugTimer() {
            debugTimerTask?.cancel()
            debugTimerTask = nil
        }

        private func debugTimerInterval() async -> Duration {
            if let schedule = await loadSchedule(),
                let interval = schedule.bpmInterval
            {
                let quartered = interval / 4
                let floor = Duration.seconds(15)
                return max(quartered, floor)
            }
            return .seconds(30)
        }
    #endif
}
