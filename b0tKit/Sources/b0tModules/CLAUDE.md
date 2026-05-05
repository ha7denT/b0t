# b0tModules

Capability bridges. Each Module wraps a slice of system access (calendar, reminders, health, time-awareness) and exposes one or more `FoundationModels.Tool`s the model can call during a turn or tick.

## Public API contracts (as-built, Phase 3)

- `Module` protocol — `static var id: String`, `var requiredPermissions: [PermissionKind]`, `var tools: [any Tool]`, `init(parameters: Frontmatter) throws`. `Sendable`.
- `PermissionKind` enum — `.calendar`, `.reminders`, `.healthRead([HKQuantityTypeIdentifier])` (last case `#if canImport(HealthKit)`-guarded).
- `ModuleRegistry.loadModules(for: Bot) async throws -> [any Module]` — public entry point. Reads `<bot>/modules/*.md`, looks up `module_id` in the static factories table, returns the instantiated set. Unknown ids and `enabled: false` are logged-and-skipped (lenient, per spec Q7).
- `ModuleLoadError` — `.missingModuleID(file: URL)`, `.invalidParameters(moduleID: String, underlying: any Error)`.
- `EventKitStore` protocol + `LiveEventKitStore` (production) + `FakeEventKitStore` (test target). Read+create surface: `authorizationStatus`, `requestAccess`, `events(matching:)`, `calendars(for:)`, `save(_:commit:)`, `fetchReminders(matching:)`, `predicateForReminders(in:)`, `defaultCalendarForNewReminders()`.
- `HealthStore` protocol (`#if canImport(HealthKit)`) + `LiveHealthStore` (`#if os(iOS)`) + `FakeHealthStore`. Surface: `authorizationStatus(for:)`, `requestAuthorization(toShare:read:)`, `stepsToday()`.
- `PermissionGate` actor (package-scoped, not re-exported). Single chokepoint for `.calendar`/`.reminders`/`.healthRead` requests. Dual-init on iOS (with both EventKit and Health backends); single-init on macOS (EventKit only).

## Public Modules + Tools

| Module | `module_id` | Permissions | Tools | Slice |
|---|---|---|---|---|
| `TimeAwarenessModule` | `time-awareness` | none | `time_awareness` | 2 |
| `CalendarModule` | `calendar` | `.calendar` | `calendar.upcoming_events` | 4 |
| `RemindersModule` | `reminders` | `.reminders` | `reminders.create`, `reminders.list` | 5 |
| `HealthModule` (iOS) | `health` | `.healthRead([.stepCount])` | `health.steps_today` | 6 |

## Patterns

- Each Module instantiates its own `PermissionGate` and injects it into its tools. `EventKitStore`/`HealthStore` are shared between gate and tools per Module instance.
- Tools that require permission conform to `PermissionAware` (in `b0tBrain`). `ContextAssembler` reads the assembled context's `toolsRequirePermission` flag (set by the wiring layer) and conditionally appends a system-prompt addendum instructing the model how to address `permissionDenied: true` results.
- Tools return `permissionDenied: true` in their typed `Output` rather than throwing. The model addresses denial in its own voice.
- HealthKit's read-permission state is opaque post-prompt — Apple's API can't reliably distinguish "denied" from "no data". Phase 3 sets `permissionDenied: false` for zero step counts; the b0t replies in voice ("you've been still today") rather than claiming denial.
- `Tool` instances are reachable from `[any Tool]` in `AssembledContext.tools`, which `LanguageModelSession(tools:)` consumes directly.
- `LanguageModelClient.generate` returns `(Output, [ToolCallRecord])`. `LiveLanguageModelClient` extracts records from `LanguageModelSession.Transcript` by pairing `.toolCalls` and `.toolOutput` entries by id (collisions on toolName would silently overwrite when the same tool is called twice — hence id-based pairing).
- `ToolCallRecord.argumentsSummary` is rendered from `GeneratedContent.jsonString` (compact JSON like `{"windowHours":24}`) rather than the verbose `String(describing:)` debug form.
- `HealthModule` and `LiveHealthStore` are platform-guarded `#if canImport(HealthKit) && os(iOS)`. On macOS-host `swift test`, the registry's factories table omits `HealthModule.id`; `default-bot/modules/health.md` becomes "unknown id, log + skip".
- Module initialisers that accept a `PermissionGate` are `package` (not `public`) because Swift forbids exposing a package-scoped type in a `public` signature. The Module struct itself is `public`; outside callers get tools via the registry, not by constructing modules directly.
- **Date serialisation uses local-timezone ISO-8601 with offset suffix**, not UTC `Z`. Format: `2026-05-05T17:00:00+10:00`. Same absolute instant as `Z`, but the wall-clock numerals match what the user sees in their Calendar/Reminders apps — the model reads the digits literally, so `Z`-suffixed UTC strings cause it to report the wrong hour for any non-UTC user. Configure with `formatter.timeZone = .current` and `formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]`. Applies to `CalendarUpcomingEventsTool.Output.Event.startISO/endISO` and `RemindersListTool.Output.Reminder.dueDateISO`. The `RemindersCreateTool.Arguments.dueDateISO` `@Guide` instructs the model to produce offset-aware ISOs in the user's timezone, not UTC.
- **EventKit predicates must come from `EKEventStore.predicateForEvents(withStart:end:calendars:)`** — `eventsMatchingPredicate:` throws `NSInvalidArgumentException` on any other `NSPredicate`. `EventKitStore.predicateForEvents(...)` exists as the seam for this; `FakeEventKitStore` returns a passthrough but the live impl forwards to `EKEventStore`. The in-memory filter on returned events uses overlap semantics (`endDate >= now && startDate <= end`) to match the predicate's behaviour and include ongoing events.

## DEBUG launch args

(no new args in Phase 3 — Phase 2's `--use-stub-client` and `--debug-heartbeat-timer` still apply)

## Manual smoke checklist (Phase 3 acceptance — verified 2026-05-05)

1. **Simulator with live FM + granted permissions:** ask "what's on my calendar today?" → grant calendar → see real events with the correct local-timezone wall-clock time. Ask "remind me to email Lin at 4pm" → grant reminders → reminder appears in iOS Reminders app. Flip `default-bot/modules/health.md` `enabled: true` and rebuild → ask "how many steps today?" → grant health → real count.
2. **Decline path:** decline calendar access → ask the same question → b0t notes the missing access in its own voice.
3. **Tool-call rendering:** `→ calendar.upcoming_events({})` and `← {events: [...]}` rows appear inline in the chat between user prompt and reply.
4. **Journal:** `**tools_called:**` sub-section appears under the turn's OpenClaw entry whenever a tool fired.

If you've previously run b0t on this simulator before Phase 3 landed, wipe the app data first (long-press app → Remove App, then reinstall) — `BotProvisioner` only copies the bundled `default-bot/` into Documents on first launch, so a stale install won't have the `modules/` directory.

## Depends on

- `b0tBrain` (`Bot`, `Frontmatter`, `BotFile`, `BotStore`, `ToolCallRecord`, `PermissionAware`)
- `b0tCore` (`Clock`, `SystemClock` — used by `TimeAwarenessTool` and the calendar tool's clock injection)
- `EventKit` (system, iOS+macOS)
- `HealthKit` (system, iOS only — `#if canImport(HealthKit) && os(iOS)`-guarded)
- `FoundationModels` (system, iOS 26+)

## Read first when working here

- `docs/specs/phase-3-modules-and-tools.md` — design contract
- `docs/plans/phase-3-modules-and-tools.md` — task-by-task implementation history
- `docs/decisions/0008-implementation-amendment-2026-05-04.md` — vocabulary lock + MCP-as-architecture-only
- `docs/decisions/0009-module-protocol-simplification.md` — Module/ToolHandle simplification (added in T31)
- `default-bot/modules/{calendar,reminders,health,time-awareness}.md` — concrete frontmatter shapes
- `b0tKit/Sources/b0tCore/CLAUDE.md` — the FM-loop contract Phase 3 extends
