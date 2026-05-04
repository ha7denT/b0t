# b0tModules

Capability bridges — typed Swift wrappers around system frameworks (EventKit, HealthKit) exposed to the model as `FoundationModels.Tool`s.

## Status

**Phase 3 in progress.** This document tracks the as-built shape mid-flight; T30 will write the final reference at phase close.

## Public API contracts (current — Phase 3, slice 2)

- `Module` protocol — `static var id: String`, `var requiredPermissions: [PermissionKind]`, `var tools: [any Tool]`, `init(parameters: Frontmatter) throws`. `Sendable`.
- `PermissionKind` enum — `.calendar`, `.reminders`, `.healthRead([HKQuantityTypeIdentifier])` (last case `#if canImport(HealthKit)`-guarded).
- `ModuleRegistry.loadModules(for: Bot) async throws -> [any Module]` — public entry point. Reads `<bot>/modules/*.md`, looks up `module_id` in the static factories table, returns the instantiated set. Unknown ids and `enabled: false` are logged-and-skipped (lenient, per spec Q7).
- `ModuleLoadError` — `.missingModuleID(file:)`, `.invalidParameters(moduleID:underlying:)`.
- `PermissionGate` actor (package-private; not re-exported).

Concrete content (slice 2 onwards):

| Module | `module_id` | Permissions | Tools | Slice |
|---|---|---|---|---|
| TimeAwarenessTool (no Module wrapper yet — T7) | `time-awareness` | none | `time_awareness` | 2 (in flight) |
| CalendarModule | `calendar` | `.calendar` | `calendar.upcoming_events` | 4 |
| RemindersModule | `reminders` | `.reminders` | `reminders.create`, `reminders.list` | 5 |
| HealthModule (iOS-only) | `health` | `.healthRead([.stepCount])` | `health.steps_today` | 6 |

## Design rationale

- `Module.tools` returns `[any Tool]` directly — no `ToolHandle` wrapper. `FoundationModels.Tool` already encodes the MCP shape via `@Generable`. See ADR-0009.
- v1 ships **only the modules listed above**. The default-bot's `modules/` directory contains 10 markdown files; Phase 3 supports 4. The other 6 (Mail, Location, Notes, Weather, Journaling, Onboarding) are unknown-id-and-skipped at registry load time. Their bridges land in Phase 3.5 or later.
- The .md file is prompt-and-behaviour; the Swift bridge is system access. Users compose behaviours from existing markdown; new system permissions ship in app updates.
- Permission requested at first tool call (not at app launch); on denial, the tool returns a typed `Output` with `permissionDenied: true` and the model addresses it in its own voice.

## Depends on

- `b0tBrain` (`Bot`, `Frontmatter`, `BotFile`, `BotStore`, `ToolCallRecord`)
- `b0tCore` (`Clock`, `SystemClock` — used by `TimeAwarenessTool` and forthcoming time-aware tools)
- `EventKit` (system, iOS+macOS — slice 4 onwards)
- `HealthKit` (system, iOS only — slice 6, `#if canImport(HealthKit) && os(iOS)`-guarded)
- `FoundationModels` (system, iOS 26+)

## Read first when working here

- `docs/specs/phase-3-modules-and-tools.md` — design contract
- `docs/plans/phase-3-modules-and-tools.md` — task-by-task implementation plan
- `docs/decisions/0008-implementation-amendment-2026-05-04.md` — vocabulary lock + MCP-as-architecture-only
- `docs/decisions/0009-module-protocol-simplification.md` — Module/ToolHandle simplification (lands in T31)
- `default-bot/modules/{calendar,reminders,health,time-awareness}.md` — concrete frontmatter shapes
- `b0tKit/Sources/b0tCore/CLAUDE.md` — the FM-loop contract Phase 3 extends
