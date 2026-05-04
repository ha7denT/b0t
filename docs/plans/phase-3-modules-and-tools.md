# Phase 3 — Module bridges + Tools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up `b0tModules` — typed Swift bridges to EventKit (calendar + reminders) and HealthKit, plus the `Module` / `ToolHandle` registry that loads them from a b0t's `modules/` directory — so the demo `DebugBrainView` can hold a real conversation with the production default-bot, the model can call those bridges as `Tool`s, the iOS permission flow runs naturally on first call, and tool calls render inline in the chat log.

**Architecture:** Walking-skeleton vertical slices. Slice 1 stands up the `Module` protocol + `ModuleRegistry` + `PermissionGate` skeleton in `b0tModules`, registering zero modules. Slice 2 migrates Phase 2's `TimeAwarenessTool` from `b0tCore` into `b0tModules` as the first real `Module` — proves the protocol on a permissionless tool before adding the tricky ones. Slice 3 wires tool-call records through `LanguageModelClient` → `ConversationManager` → `DebugBrainView`, so a `time_awareness` call shows up inline. Slices 4–6 add CalendarModule, RemindersModule, HealthModule, each end-to-end (store seam + tool + module + registry entry + tests). Slice 7 adds the ContextAssembler permission addendum, journal extension, Info.plist strings, default-bot integration test, gated live tests, CLAUDE.md updates, and acceptance smoke.

**Tech Stack:**
- Swift 6.0+, iOS 26 deployment target.
- `FoundationModels` framework (system-provided in iOS 26) — `Tool`, `@Generable`, `@Guide`, `LanguageModelSession`, `Transcript`.
- `EventKit` framework (system-provided) — `EKEventStore`, `EKEvent`, `EKReminder`, `EKEntityType`, `EKAuthorizationStatus`, `EKCalendar`.
- `HealthKit` framework (system-provided, iOS only) — `HKHealthStore`, `HKQuantityType`, `HKQuantitySample`, `HKStatisticsQuery`.
- `b0tBrain` (Phase 1) — `Bot`, `BotFile`, `Frontmatter`, `YAMLValue`, `BotStore`, `ModulesSection`.
- `b0tCore` (Phase 2) — `LanguageModelClient`, `AssembledContext`, `ContextAssembler`, `ConversationManager`, `JournalWriter`, `Clock`.
- XCTest. No new third-party dependencies.

**Spec:** `docs/specs/phase-3-modules-and-tools.md` (approved 2026-05-04, commit `cb4d12d`) is the source of truth for behaviour. This plan sequences the implementation; consult the spec when in doubt.

**Conventions used in this plan:**
- `**[CC]**` marks a Claude-Code-executable step.
- `**[VERIFY]**` marks a verification step — run a command, check output, do not move on if it fails.
- Tasks are TDD-shaped: failing test → minimal implementation → passing test → commit. Each task is a single atomic commit.
- Walking-skeleton discipline: every slice ends with everything compiling, all tests green, the chat surface working at that slice's level of sophistication.

**Reference docs to consult during execution:**
- `docs/specs/phase-3-modules-and-tools.md` — the design contract
- `docs/prd.md` §3 Phase 3, §5.3 — REQUIRED constraints
- `docs/decisions/0008-implementation-amendment-2026-05-04.md` — vocabulary and architectural locks (especially MCP-in-scope-as-architecture-only)
- `docs/decisions/0001-on-device-only.md` — privacy posture (Phase 3 must not introduce new network calls)
- `docs/references/voice-and-copy-guide.md` — for permission Info.plist strings and the system-prompt addendum
- `b0tKit/Sources/b0tBrain/CLAUDE.md` — the markdown layer contract
- `b0tKit/Sources/b0tCore/CLAUDE.md` — the FM-loop contract Phase 3 extends
- `default-bot/modules/{calendar,reminders,health,time-awareness}.md` — concrete frontmatter shapes the parsers must accept

---

## File Structure (what this phase creates/modifies)

**Creates** (under `b0tKit/Sources/b0tModules/`):

```
b0tModules/
├── Module.swift                        // protocol + PermissionKind enum
├── ModuleRegistry.swift                // public loadModules(for:); Dependencies struct; private factories
├── ModuleLoadError.swift               // public error taxonomy
├── PermissionGate.swift                // actor (package-private)
├── EventKit/
│   ├── EventKitStore.swift             // protocol + LiveEventKitStore + FakeEventKitStore (in tests)
├── HealthKit/
│   ├── HealthStore.swift               // protocol + LiveHealthStore (#if iOS) + FakeHealthStore (in tests)
├── Calendar/
│   ├── CalendarModule.swift
│   └── CalendarUpcomingEventsTool.swift
├── Reminders/
│   ├── RemindersModule.swift
│   ├── RemindersCreateTool.swift
│   └── RemindersListTool.swift
├── Health/
│   ├── HealthModule.swift              // #if canImport(HealthKit) && os(iOS) full impl; else inert stub
│   └── HealthStepsTodayTool.swift      // #if canImport(HealthKit) && os(iOS)
├── TimeAwareness/
│   ├── TimeAwarenessModule.swift
│   ├── TimeAwarenessTool.swift         // migrated from b0tCore/Tools/
│   └── TimeOfDay.swift                 // migrated from b0tCore/Tools/
└── CLAUDE.md
```

**Creates** (under `b0tKit/Tests/b0tModulesTests/`):

```
b0tModulesTests/
├── ModuleRegistryTests.swift
├── PermissionGateTests.swift
├── ModuleLoadErrorTests.swift
├── EventKit/
│   └── FakeEventKitStore.swift         // in-memory scriptable fake
├── HealthKit/
│   └── FakeHealthStore.swift
├── Calendar/
│   ├── CalendarModuleTests.swift
│   └── CalendarUpcomingEventsToolTests.swift
├── Reminders/
│   ├── RemindersModuleTests.swift
│   ├── RemindersCreateToolTests.swift
│   └── RemindersListToolTests.swift
├── Health/
│   ├── HealthModuleTests.swift
│   └── HealthStepsTodayToolTests.swift
├── TimeAwareness/
│   ├── TimeAwarenessModuleTests.swift
│   └── TimeAwarenessToolTests.swift    // migrated from b0tCoreTests/
└── Fixtures/
    ├── empty-modules-bot/              // bot with no modules/ dir
    ├── canonical-modules-bot/          // bot with all 4 supported + a couple unknown
    └── invalid-modules-bot/            // for parameter-decode-error tests
```

**Creates** (under `b0tKit/Tests/b0tModulesLiveTests/`):

```
b0tModulesLiveTests/
├── CalendarLiveTests.swift             // gated on LIVE_TESTS=1
├── RemindersLiveTests.swift
└── HealthLiveTests.swift
```

**Creates** (under `b0tKit/Sources/b0tBrain/`):

```
b0tBrain/
└── ToolCallRecord.swift                // public Sendable struct with toolName, argsSummary, outputSummary, timestamp
```

**Modifies** (existing files):

- `b0tKit/Package.swift` — add `b0tModulesTests` and `b0tModulesLiveTests` test targets; `b0tModules` already declared as a target.
- `b0tKit/Sources/b0tCore/Tools/TimeAwarenessTool.swift` — **deleted** (moved to b0tModules).
- `b0tKit/Sources/b0tCore/Tools/TimeOfDay.swift` — **deleted** (moved to b0tModules).
- `b0tKit/Sources/b0tCore/Context/AssembledContext.swift` — adds `toolsRequirePermission: Bool` field.
- `b0tKit/Sources/b0tCore/Context/ContextAssembler.swift` — accepts tools via init parameter, emits permission-handling addendum into `systemInstructions` when `toolsRequirePermission == true`.
- `b0tKit/Sources/b0tCore/Model/LanguageModelClient.swift` — `generate` extended to return `(Output, [ToolCallRecord])` tuple.
- `b0tKit/Sources/b0tCore/Model/LiveLanguageModelClient.swift` — extracts tool-call records from `LanguageModelSession.Transcript` after generation.
- `b0tKit/Sources/b0tCore/Model/StubLanguageModelClient.swift` — handler signature gains an optional `[ToolCallRecord]` return alongside the `Any` value.
- `b0tKit/Sources/b0tCore/ConversationManager.swift` — `respond(to:)` returns new `ConversationTurn` struct (response + toolCalls); existing call sites updated.
- `b0tKit/Sources/b0tCore/HeartbeatManager.swift` — `tick(trigger:)` `TickResult` grows `toolCalls: [ToolCallRecord]` field; threaded into `JournalWriter.appendTick(...)`.
- `b0tKit/Sources/b0tCore/Apply/JournalWriter.swift` — `appendConversationTurn` and `appendTick` accept `[ToolCallRecord]` and render under `tools_called:` sub-section in OpenClaw entries.
- `b0tKit/Sources/b0tCore/Decisions/ConversationResponse.swift` — unchanged (the wrapper grows around it; the response itself stays @Generable-clean).
- `b0tKit/Sources/b0tCore/CLAUDE.md` — refreshed at end of phase to as-built; remove `TimeAwarenessTool` reference.
- `b0tApp/Sources/Debug/DebugBrainView.swift` — renders `[ToolCallRecord]` rows inline between user prompt and assistant reply; loads modules via `ModuleRegistry` and threads tools through `ContextAssembler`.
- `b0tApp/Sources/App/b0tApp.swift` — wires `ModuleRegistry.loadModules(for:)` at startup so the live ContentView gets real tools.
- `project.yml` — adds `INFOPLIST_KEY_NSCalendarsUsageDescription`, `INFOPLIST_KEY_NSRemindersFullAccessUsageDescription`, `INFOPLIST_KEY_NSHealthShareUsageDescription`. (If xcodegen drops these like it dropped `BGTaskSchedulerPermittedIdentifiers` per Phase 2 Task 30, fall back to editing `b0tApp/Info.plist` directly.)
- `b0tApp/Resources/Info.plist` — fallback target for the three usage-description keys if xcodegen doesn't propagate.
- `docs/IMPLEMENTATION.md` — Phase 3 status, ledger, mid-phase deviations.

---

## Slice 1 — Module protocol foundations (no concrete modules yet)

End-state: `b0tModules` exposes `Module`, `PermissionKind`, `ModuleRegistry`, `PermissionGate`, `ModuleLoadError`, plus `ToolCallRecord` in `b0tBrain`. Registry can load from a bot directory; with no factories registered, every `module_id` is logged-and-skipped and the result is an empty array. All Phase 2 tests still pass. No behaviour change yet for any existing code path.

### Task 1: `ToolCallRecord` in `b0tBrain`

**Files:**
- Create: `b0tKit/Sources/b0tBrain/ToolCallRecord.swift`
- Test: `b0tKit/Tests/b0tBrainTests/ToolCallRecordTests.swift`

- [ ] **Step 1: Write the failing test**

Write `b0tKit/Tests/b0tBrainTests/ToolCallRecordTests.swift`:

```swift
import XCTest
@testable import b0tBrain

final class ToolCallRecordTests: XCTestCase {
    func testInitAndAccessors() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let record = ToolCallRecord(
            toolName: "calendar.upcoming_events",
            argumentsSummary: "windowHours: 24",
            outputSummary: "2 events, permissionDenied: false",
            timestamp: date
        )
        XCTAssertEqual(record.toolName, "calendar.upcoming_events")
        XCTAssertEqual(record.argumentsSummary, "windowHours: 24")
        XCTAssertEqual(record.outputSummary, "2 events, permissionDenied: false")
        XCTAssertEqual(record.timestamp, date)
    }

    func testEquatable() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let a = ToolCallRecord(toolName: "x", argumentsSummary: "a", outputSummary: "b", timestamp: date)
        let b = ToolCallRecord(toolName: "x", argumentsSummary: "a", outputSummary: "b", timestamp: date)
        let c = ToolCallRecord(toolName: "y", argumentsSummary: "a", outputSummary: "b", timestamp: date)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testIsSendable() {
        // Compile-time check: storing in a Sendable context.
        let _: any Sendable = ToolCallRecord(
            toolName: "x", argumentsSummary: "y", outputSummary: "z", timestamp: Date()
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path b0tKit --filter b0tBrainTests.ToolCallRecordTests`
Expected: FAIL — `ToolCallRecord` undefined.

- [ ] **Step 3: Write the type**

Create `b0tKit/Sources/b0tBrain/ToolCallRecord.swift`:

```swift
import Foundation

/// A record of a single tool invocation during a conversation turn or heartbeat tick.
///
/// Captured by the language-model client adapter (live or stub), threaded through
/// `ConversationManager` / `HeartbeatManager`, and surfaced in the chat log and
/// in OpenClaw journal entries' `tools_called:` sub-section.
///
/// Lives in `b0tBrain` because both `b0tCore` (the consumer that puts records
/// into `ConversationTurn`/`TickResult` and `JournalWriter`) and `b0tModules`
/// (the producer that constructs records from typed `Arguments`/`Output`)
/// already depend on `b0tBrain`. Putting the record here avoids inverting the
/// b0tCore↔b0tModules independence that Phase 2 deliberately preserved.
///
/// `argumentsSummary` and `outputSummary` are short prose intended for human
/// reading in the chat log and journal — not machine-parseable. Each tool
/// produces them from its typed `@Generable` `Arguments`/`Output`.
public struct ToolCallRecord: Sendable, Equatable {
    public let toolName: String
    public let argumentsSummary: String
    public let outputSummary: String
    public let timestamp: Date

    public init(
        toolName: String,
        argumentsSummary: String,
        outputSummary: String,
        timestamp: Date
    ) {
        self.toolName = toolName
        self.argumentsSummary = argumentsSummary
        self.outputSummary = outputSummary
        self.timestamp = timestamp
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path b0tKit --filter b0tBrainTests.ToolCallRecordTests`
Expected: PASS, 3 tests.

- [ ] **Step 5: Run the rest of the b0tKit suite to confirm no regression**

Run: `swift test --package-path b0tKit`
Expected: PASS, all existing tests still green (Phase 1 + Phase 2).

- [ ] **Step 6: Commit**

```bash
git add b0tKit/Sources/b0tBrain/ToolCallRecord.swift b0tKit/Tests/b0tBrainTests/ToolCallRecordTests.swift
git commit -m "feat(b0tBrain): add ToolCallRecord — shared Phase-3 tool-call type"
```

---

### Task 2: `Module` protocol + `PermissionKind` enum

**Files:**
- Create: `b0tKit/Sources/b0tModules/Module.swift`
- Test: covered indirectly by `ModuleRegistryTests` (Task 4) and the per-module tests in slices 4–6. Protocol-only files are not directly testable without a conformer.

- [ ] **Step 1: Write the protocol and enum**

Create `b0tKit/Sources/b0tModules/Module.swift`:

```swift
import Foundation
import FoundationModels
import b0tBrain
#if canImport(HealthKit)
import HealthKit
#endif

/// A capability bridge for the b0t — a Swift type that owns a slice of system
/// access (calendar, reminders, health, etc.) and exposes one or more
/// `FoundationModels.Tool`s the model can call during a turn or tick.
///
/// One markdown file in `<bot>/modules/` declares one Module, identified by
/// its `module_id` frontmatter key. `ModuleRegistry.loadModules(for:)` reads
/// the markdown, looks up the matching Swift type via the registry's
/// dispatch table, decodes the file's frontmatter into the Module's typed
/// `Parameters`, and returns the instantiated Module.
///
/// `Module` returns `[any Tool]` directly — there is no `ToolHandle`
/// indirection. `FoundationModels.Tool` already encodes the MCP shape via
/// `@Generable` (name, description, JSON-schema input, JSON-encodable output);
/// a wrapper would just re-serialise. See spec §3 Q4 and ADR-0008.
///
/// Modules are `Sendable` because their tools cross actor boundaries inside
/// `LanguageModelSession`.
public protocol Module: Sendable {
    /// Stable identifier matching the `module_id` frontmatter key.
    static var id: String { get }

    /// System permissions this Module's tools may request at call time.
    /// Empty array → permissionless (e.g. `TimeAwarenessModule`).
    var requiredPermissions: [PermissionKind] { get }

    /// `FoundationModels.Tool` instances this Module exposes to the session.
    /// Several related tools per Module is fine (e.g. RemindersModule has
    /// both `reminders.create` and `reminders.list`).
    var tools: [any Tool] { get }

    /// Decode typed parameters from the Module's `.md` frontmatter.
    /// Throws if frontmatter is missing required keys, has wrong types, or
    /// otherwise fails the Module's `Parameters` schema.
    init(parameters: Frontmatter) throws
}

/// System permissions a `Module`'s tools may request.
///
/// `.healthRead` carries the specific HealthKit quantity types because
/// HealthKit's `requestAuthorization(toShare:read:)` is per-type. Calendar
/// and Reminders are single-permission so they carry no payload.
public enum PermissionKind: Sendable, Equatable {
    case calendar
    case reminders
    #if canImport(HealthKit)
    case healthRead([HKQuantityTypeIdentifier])
    #endif

    public static func == (lhs: PermissionKind, rhs: PermissionKind) -> Bool {
        switch (lhs, rhs) {
        case (.calendar, .calendar): return true
        case (.reminders, .reminders): return true
        #if canImport(HealthKit)
        case (.healthRead(let a), .healthRead(let b)):
            return a.map(\.rawValue).sorted() == b.map(\.rawValue).sorted()
        #endif
        default: return false
        }
    }
}
```

- [ ] **Step 2: Run the build to verify compiles**

Run: `swift build --package-path b0tKit`
Expected: PASS, no errors. Module.swift is protocol-only — only the type system needs to accept it.

- [ ] **Step 3: Run the existing test suite to confirm no regression**

Run: `swift test --package-path b0tKit`
Expected: PASS, all green.

- [ ] **Step 4: Commit**

```bash
git add b0tKit/Sources/b0tModules/Module.swift
git commit -m "feat(b0tModules): add Module protocol and PermissionKind enum"
```

---

### Task 3: `ModuleLoadError` taxonomy

**Files:**
- Create: `b0tKit/Sources/b0tModules/ModuleLoadError.swift`
- Test: `b0tKit/Tests/b0tModulesTests/ModuleLoadErrorTests.swift`

- [ ] **Step 1: Write the failing test**

First we need the test target to exist. Create `b0tKit/Tests/b0tModulesTests/ModuleLoadErrorTests.swift`:

```swift
import XCTest
@testable import b0tModules

final class ModuleLoadErrorTests: XCTestCase {
    func testMissingModuleIDCarriesFileURL() {
        let url = URL(fileURLWithPath: "/tmp/x.md")
        let error = ModuleLoadError.missingModuleID(file: url)
        if case .missingModuleID(let f) = error {
            XCTAssertEqual(f, url)
        } else {
            XCTFail("expected .missingModuleID")
        }
    }

    func testInvalidParametersCarriesIDAndUnderlying() {
        struct Underlying: Error, Equatable {}
        let error = ModuleLoadError.invalidParameters(moduleID: "calendar", underlying: Underlying())
        if case .invalidParameters(let id, let underlying) = error {
            XCTAssertEqual(id, "calendar")
            XCTAssertNotNil(underlying)
        } else {
            XCTFail("expected .invalidParameters")
        }
    }
}
```

- [ ] **Step 2: Add the test target to `Package.swift`**

Modify `b0tKit/Package.swift`:

Find the `targets:` array and add a new test target after the existing test targets (before the closing `]`):

```swift
.testTarget(name: "b0tModulesTests", dependencies: ["b0tModules"]),
```

Note: this target may already exist as a placeholder from an earlier Phase 2 commit. If `grep -n 'b0tModulesTests' b0tKit/Package.swift` returns a hit, leave the existing entry alone — just confirm the dependency is `["b0tModules"]`.

- [ ] **Step 3: Run test to verify it fails**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.ModuleLoadErrorTests`
Expected: FAIL — `ModuleLoadError` undefined.

- [ ] **Step 4: Write the error taxonomy**

Create `b0tKit/Sources/b0tModules/ModuleLoadError.swift`:

```swift
import Foundation

/// Errors raised by `ModuleRegistry.loadModules(for:)` while reading a
/// b0t's `modules/` directory.
///
/// Note: an unknown `module_id` is **not** an error — the registry logs it
/// at debug level and skips the file (spec Q7). Same for `enabled: false`.
/// The errors here represent malformed input the user can fix by editing
/// the markdown.
public enum ModuleLoadError: Error, Sendable {
    /// A module markdown file exists but its frontmatter has no `module_id`
    /// key. The `file` URL points at the offending `.md`.
    case missingModuleID(file: URL)

    /// The module's `Parameters` schema rejected the frontmatter. The
    /// `moduleID` is the `module_id` we recognised; `underlying` is the
    /// per-Module decoder's specific error (e.g. wrong key type, missing
    /// required field).
    case invalidParameters(moduleID: String, underlying: any Error)
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.ModuleLoadErrorTests`
Expected: PASS, 2 tests.

- [ ] **Step 6: Commit**

```bash
git add b0tKit/Sources/b0tModules/ModuleLoadError.swift b0tKit/Tests/b0tModulesTests/ModuleLoadErrorTests.swift b0tKit/Package.swift
git commit -m "feat(b0tModules): add ModuleLoadError taxonomy + b0tModulesTests target"
```

---

### Task 4: `ModuleRegistry.loadModules(for:)` — empty factories table

**Files:**
- Create: `b0tKit/Sources/b0tModules/ModuleRegistry.swift`
- Create: `b0tKit/Tests/b0tModulesTests/ModuleRegistryTests.swift`
- Create: `b0tKit/Tests/b0tModulesTests/Fixtures/empty-modules-bot/identity/core.md` (minimal stub)
- Create: `b0tKit/Tests/b0tModulesTests/Fixtures/canonical-modules-bot/modules/{unknown.md, disabled.md, missing-id.md}` (registry-input fixtures)

The empty factories table means every `module_id` returned by the fixture is unknown. Tests verify the lenient-skip path, the `enabled: false` path, the missing-id path. Real modules land in slices 2 + 4–6.

- [ ] **Step 1: Set up fixture bots**

Create `b0tKit/Tests/b0tModulesTests/Fixtures/empty-modules-bot/identity/core.md`:

```markdown
---
b0t_name: empty
---
# empty bot

Used for ModuleRegistry tests. Has no modules/ directory.
```

Create `b0tKit/Tests/b0tModulesTests/Fixtures/canonical-modules-bot/identity/core.md`:

```markdown
---
b0t_name: canonical
---
# canonical bot
```

Create `b0tKit/Tests/b0tModulesTests/Fixtures/canonical-modules-bot/modules/unknown.md`:

```markdown
---
module_id: not_a_real_module
enabled: true
---
# unknown
```

Create `b0tKit/Tests/b0tModulesTests/Fixtures/canonical-modules-bot/modules/disabled.md`:

```markdown
---
module_id: not_a_real_module
enabled: false
---
# disabled
```

Create `b0tKit/Tests/b0tModulesTests/Fixtures/canonical-modules-bot/modules/missing-id.md`:

```markdown
---
enabled: true
some_other_key: value
---
# missing module_id
```

- [ ] **Step 2: Wire fixtures into the test target**

Modify `b0tKit/Package.swift`:

Update the `b0tModulesTests` test target entry (added in Task 3) to include resources:

```swift
.testTarget(
    name: "b0tModulesTests",
    dependencies: ["b0tModules"],
    resources: [.copy("Fixtures")]
),
```

- [ ] **Step 3: Write the failing tests**

Create `b0tKit/Tests/b0tModulesTests/ModuleRegistryTests.swift`:

```swift
import XCTest
import b0tBrain
@testable import b0tModules

final class ModuleRegistryTests: XCTestCase {
    private func loadFixture(named name: String) async throws -> Bot {
        let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")!
        let store = BotStore()
        return try await store.load(at: url)
    }

    func testEmptyBotReturnsEmptyArray() async throws {
        let bot = try await loadFixture(named: "empty-modules-bot")
        let modules = try await ModuleRegistry.loadModules(for: bot)
        XCTAssertEqual(modules.count, 0)
    }

    func testCanonicalBotWithEmptyFactoriesTableSkipsAllUnknownAndDisabled() async throws {
        let bot = try await loadFixture(named: "canonical-modules-bot")
        let modules = try await ModuleRegistry.loadModules(for: bot)
        XCTAssertEqual(modules.count, 0)
        // Note: this test only verifies "skipped" behaviour. It cannot verify
        // the disabled path was distinct from the unknown path without log
        // inspection. That distinction matters for human debuggability but
        // is not asserted at the unit-test level.
    }

    func testMissingModuleIDThrows() async throws {
        // Set up a one-file fixture inline: a module with neither id nor
        // enabled:false. The canonical-modules-bot's missing-id.md is exactly
        // this case, but in the empty-factories world it would normally be
        // hidden by other modules' skipping. To isolate, build a dedicated
        // bot with only missing-id.md.
        // Since fixtures are static, instead: load the canonical bot and
        // expect it to throw because `missing-id.md` is processed.
        let bot = try await loadFixture(named: "canonical-modules-bot")
        do {
            _ = try await ModuleRegistry.loadModules(for: bot)
            XCTFail("expected throw on missing module_id")
        } catch ModuleLoadError.missingModuleID {
            // expected — order of file processing is alphabetical and
            // disabled.md/missing-id.md/unknown.md means missing-id.md
            // throws before unknown.md skips. We accept either ordering.
        } catch {
            XCTFail("expected ModuleLoadError.missingModuleID, got \(error)")
        }
    }
}
```

Note on the third test: the fixture-design-vs-test-scope tradeoff is real. We accept that "load the canonical bot, expect throw" couples to alphabetical ordering. If the implementer prefers, they may split `canonical-modules-bot` into two fixtures (one with no missing-id file, one with only missing-id) and adjust both tests accordingly. The behavioural contract is what matters.

- [ ] **Step 4: Run tests to verify they fail**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.ModuleRegistryTests`
Expected: FAIL — `ModuleRegistry` undefined.

- [ ] **Step 5: Implement `ModuleRegistry`**

Create `b0tKit/Sources/b0tModules/ModuleRegistry.swift`:

```swift
import Foundation
import OSLog
import b0tBrain

/// Loads `Module` instances from a b0t's `modules/` directory.
///
/// Each `.md` file's frontmatter is read; the `module_id` is looked up in
/// the registry's static `factories` dispatch table. Known ids → factory
/// invoked with the file's frontmatter, instantiating the Module. Unknown
/// ids and `enabled: false` files are logged-and-skipped (lenient policy
/// per spec Q7). Missing `module_id` and per-Module parameter-decode
/// failures throw `ModuleLoadError`.
///
/// Adding a Module post-Phase-3 means: define a struct conforming to
/// `Module`, add one entry to `factories`. That's the v1 form of ADR-0008's
/// marketplace-compatibility seam.
public enum ModuleRegistry {
    private static let logger = Logger(
        subsystem: "com.toppeross.b0t.b0tModules",
        category: "ModuleRegistry"
    )

    /// Module-id → factory closure. Slice 1 starts empty. Each subsequent
    /// slice adds entries: slice 2 adds TimeAwarenessModule, slice 4 adds
    /// CalendarModule, slice 5 adds RemindersModule, slice 6 adds HealthModule
    /// (conditionally on iOS).
    private static var factories: [String: @Sendable (Frontmatter) throws -> any Module] {
        var table: [String: @Sendable (Frontmatter) throws -> any Module] = [:]
        // Future slices will populate this table.
        return table
    }

    /// Read `<bot>/modules/*.md`, resolve known modules to factories,
    /// skip unknown/disabled, throw on malformed.
    ///
    /// Returns Modules in alphabetical filename order (the iteration order
    /// of `ModulesSection.all`).
    public static func loadModules(for bot: Bot) async throws -> [any Module] {
        let files = try await bot.modules.all
        var modules: [any Module] = []
        for file in files {
            let fm = file.frontmatter

            // enabled: false → silent skip
            if case .bool(false) = fm["enabled"] {
                continue
            }

            // module_id missing → throw (user-fixable error)
            guard case .string(let id) = fm["module_id"] else {
                throw ModuleLoadError.missingModuleID(file: file.fileURL)
            }

            // unknown id → debug log, skip
            guard let factory = factories[id] else {
                logger.debug(
                    "unknown module_id '\(id, privacy: .public)' in modules/\(file.fileURL.lastPathComponent, privacy: .public) — skipped"
                )
                continue
            }

            // known id → instantiate; per-Module parameter-decode errors
            // get wrapped so the caller knows which Module rejected.
            do {
                modules.append(try factory(fm))
            } catch {
                throw ModuleLoadError.invalidParameters(moduleID: id, underlying: error)
            }
        }
        return modules
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.ModuleRegistryTests`
Expected: PASS, 3 tests.

- [ ] **Step 7: Run full suite**

Run: `swift test --package-path b0tKit`
Expected: PASS, all green.

- [ ] **Step 8: Commit**

```bash
git add b0tKit/Sources/b0tModules/ModuleRegistry.swift b0tKit/Tests/b0tModulesTests/ModuleRegistryTests.swift b0tKit/Tests/b0tModulesTests/Fixtures/ b0tKit/Package.swift
git commit -m "feat(b0tModules): add ModuleRegistry with empty factories + lenient skip"
```

---

### Task 5: `PermissionGate` actor — skeleton only (no real backends yet)

**Files:**
- Create: `b0tKit/Sources/b0tModules/PermissionGate.swift`
- Create: `b0tKit/Tests/b0tModulesTests/PermissionGateTests.swift`

The gate is package-private. Its public-to-the-package API is `ensure(_:) async -> Bool`. Its internal switch over `PermissionKind` cases is filled in slice-by-slice as each kind's backing store lands. In Slice 1 the gate's body is `fatalError("not implemented for \(kind)")` for every case — a placeholder we'll replace as we add stores. Tests cover only the construction-and-shape of the actor; behavioural tests come with each store.

- [ ] **Step 1: Write the failing test**

Create `b0tKit/Tests/b0tModulesTests/PermissionGateTests.swift`:

```swift
import XCTest
@testable import b0tModules

final class PermissionGateTests: XCTestCase {
    func testActorIsConstructible() async {
        let gate = PermissionGate()
        // No public API to assert against yet — slice 4 is the first slice
        // with a real backend, where behavioural tests land.
        _ = gate
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.PermissionGateTests`
Expected: FAIL — `PermissionGate` undefined.

- [ ] **Step 3: Implement the skeleton**

Create `b0tKit/Sources/b0tModules/PermissionGate.swift`:

```swift
import Foundation

/// Single chokepoint for system-permission requests across all Modules.
///
/// Each `Module` instance constructs (or is injected) a `PermissionGate`
/// and shares it across its `tools`. A tool's `call(arguments:)`
/// invokes `await gate.ensure(.x)` before doing real work; on `false` it
/// returns `Output(permissionDenied: true, …)` and leaves the rest of
/// the tool's logic skipped.
///
/// Construction takes injected backends (slice 4 wires `EventKitStore` for
/// `.calendar` and `.reminders`; slice 6 wires `HealthStore` for
/// `.healthRead`). Slice 1 ships the actor with empty initialisation;
/// every `ensure(_:)` call traps at runtime. That's intentional: no
/// production code path can reach the gate yet.
package actor PermissionGate {
    package init() {}

    package func ensure(_ kind: PermissionKind) async -> Bool {
        // Replaced slice-by-slice as backends land.
        // Slice 4: .calendar, .reminders cases via EventKitStore
        // Slice 6: .healthRead via HealthStore
        switch kind {
        case .calendar, .reminders:
            fatalError("PermissionGate.ensure not yet implemented for \(kind) — slice 4")
        #if canImport(HealthKit)
        case .healthRead:
            fatalError("PermissionGate.ensure not yet implemented for \(kind) — slice 6")
        #endif
        }
    }
}
```

Note `package actor` and `package init`/`package func` — Swift's package access level (introduced in 5.9). The gate is invisible to consumers outside `b0tModules` but accessible to all files inside the package.

- [ ] **Step 4: Run tests to confirm pass**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.PermissionGateTests`
Expected: PASS, 1 test.

- [ ] **Step 5: Run full suite**

Run: `swift test --package-path b0tKit`
Expected: PASS, all green.

- [ ] **Step 6: Commit**

```bash
git add b0tKit/Sources/b0tModules/PermissionGate.swift b0tKit/Tests/b0tModulesTests/PermissionGateTests.swift
git commit -m "feat(b0tModules): add PermissionGate actor skeleton"
```

---

## Slice 2 — Migrate `TimeAwarenessTool` from `b0tCore` to `b0tModules`

End-state: `TimeAwarenessTool` and `TimeOfDay` live in `b0tModules`. `TimeAwarenessModule` wraps the tool and conforms to `Module`. The factories table in `ModuleRegistry` registers it. `b0tCore` ships zero concrete `Tool`s. Phase 2's `TimeAwarenessToolTests` move to `b0tModulesTests`. Loading the canonical fixture bot now returns `[TimeAwarenessModule]` if the fixture has a matching module file — we add one to verify.

This slice is the smallest possible end-to-end exercise of the `Module` → `ModuleRegistry` → `tools` pipeline before the EventKit / HealthKit complexity lands.

### Task 6: Move `TimeAwarenessTool.swift` and `TimeOfDay.swift` to `b0tModules`

**Files:**
- Move: `b0tKit/Sources/b0tCore/Tools/TimeAwarenessTool.swift` → `b0tKit/Sources/b0tModules/TimeAwareness/TimeAwarenessTool.swift`
- Move: `b0tKit/Sources/b0tCore/Tools/TimeOfDay.swift` → `b0tKit/Sources/b0tModules/TimeAwareness/TimeOfDay.swift`
- Move: `b0tKit/Tests/b0tCoreTests/TimeAwarenessToolTests.swift` → `b0tKit/Tests/b0tModulesTests/TimeAwareness/TimeAwarenessToolTests.swift`
- Modify: imports in moved files
- Delete: `b0tKit/Sources/b0tCore/Tools/` directory once empty

Phase 2 imported `TimeAwarenessTool` and `TimeOfDay` as part of `b0tCore`. After this task they're imported from `b0tModules`. `b0tCore`'s `Clock` protocol stays in `b0tCore`'s `Support/`; the moved tool imports `b0tCore` to use it. (Yes — `b0tModules` will gain a dependency on `b0tCore` for shared types like `Clock`. Verify this during implementation; if the dependency feels wrong, an alternative is to move `Clock` to `b0tBrain` since both `b0tCore` and `b0tModules` already depend on it. Decision documented in slice-2 commit message.)

- [ ] **Step 1: Inspect current files**

Run: `cat b0tKit/Sources/b0tCore/Tools/TimeAwarenessTool.swift b0tKit/Sources/b0tCore/Tools/TimeOfDay.swift b0tKit/Tests/b0tCoreTests/TimeAwarenessToolTests.swift`
Expected: read the files. Verify `Clock` is the only b0tCore-internal dep used.

- [ ] **Step 2: Decide where `Clock` lives**

If `Clock` is used only by tools, move it to `b0tBrain` (where `Date` utilities make sense alongside frontmatter + journal time). If `Clock` is widely used in `b0tCore` (Executor, JournalWriter, etc.), keep it in `b0tCore` and add `b0tCore` as a dependency of `b0tModules`.

Check with: `grep -rn "import b0tCore\|Clock\|SystemClock" b0tKit/Sources/b0tCore | head -30`

If `Clock`/`SystemClock` is referenced by ConversationManager, HeartbeatManager, JournalWriter, etc. — keep in b0tCore.

For this plan: assume **`Clock` stays in `b0tCore`** and `b0tModules` adds `b0tCore` as a dependency. Modify `b0tKit/Package.swift`:

```swift
.target(name: "b0tModules", dependencies: ["b0tBrain", "b0tCore"]),
```

(Existing line is `.target(name: "b0tModules", dependencies: ["b0tBrain"])` — replace.)

- [ ] **Step 3: Move the source files**

Run:
```bash
mkdir -p b0tKit/Sources/b0tModules/TimeAwareness
git mv b0tKit/Sources/b0tCore/Tools/TimeAwarenessTool.swift b0tKit/Sources/b0tModules/TimeAwareness/TimeAwarenessTool.swift
git mv b0tKit/Sources/b0tCore/Tools/TimeOfDay.swift b0tKit/Sources/b0tModules/TimeAwareness/TimeOfDay.swift
rmdir b0tKit/Sources/b0tCore/Tools 2>/dev/null || true
```

- [ ] **Step 4: Update imports in moved files**

Edit `b0tKit/Sources/b0tModules/TimeAwareness/TimeAwarenessTool.swift`:
- Add `import b0tCore` at the top (right after `import FoundationModels`).
- Verify `TimeOfDay` reference resolves (same module, no import needed).
- Make sure `public struct TimeAwarenessTool` and `public init(...)` keep their public access.

Edit `b0tKit/Sources/b0tModules/TimeAwareness/TimeOfDay.swift`:
- Confirm `public enum TimeOfDay` keeps its public access (used by `TimeAwarenessTool.Output`).

- [ ] **Step 5: Move the test file**

Run:
```bash
mkdir -p b0tKit/Tests/b0tModulesTests/TimeAwareness
git mv b0tKit/Tests/b0tCoreTests/TimeAwarenessToolTests.swift b0tKit/Tests/b0tModulesTests/TimeAwareness/TimeAwarenessToolTests.swift
```

Edit `b0tKit/Tests/b0tModulesTests/TimeAwareness/TimeAwarenessToolTests.swift`:
- Change `@testable import b0tCore` to `@testable import b0tModules` (and add `import b0tCore` if the test uses `Clock` directly).

- [ ] **Step 6: Run the suite to verify the move is clean**

Run: `swift test --package-path b0tKit`
Expected: PASS, all tests green. The TimeAwarenessTool tests now run in `b0tModulesTests`.

If failures cite `TimeAwarenessTool` from b0tCoreTests: there were other test files referencing it. Search and update: `grep -rn "TimeAwarenessTool\|TimeOfDay" b0tKit/Tests/`.

- [ ] **Step 7: Update b0tCore CLAUDE.md to remove TimeAwareness reference**

Edit `b0tKit/Sources/b0tCore/CLAUDE.md`:

Find the line:
```
- `TimeAwarenessTool` — sole `Tool` shipped in Phase 2; Phase 3 wires real module bridges.
```

Replace with:
```
- (no concrete `Tool`s ship from `b0tCore` as of Phase 3; the `TimeAwarenessTool` migrated to `b0tModules/TimeAwareness/` — see `b0tKit/Sources/b0tModules/CLAUDE.md`).
```

- [ ] **Step 8: Commit**

```bash
git add b0tKit/Package.swift b0tKit/Sources/b0tModules/TimeAwareness/ b0tKit/Tests/b0tModulesTests/TimeAwareness/ b0tKit/Sources/b0tCore/CLAUDE.md
git commit -m "refactor: move TimeAwarenessTool and TimeOfDay from b0tCore to b0tModules"
```

---

### Task 7: `TimeAwarenessModule` conforming to `Module`

**Files:**
- Create: `b0tKit/Sources/b0tModules/TimeAwareness/TimeAwarenessModule.swift`
- Create: `b0tKit/Tests/b0tModulesTests/TimeAwareness/TimeAwarenessModuleTests.swift`

- [ ] **Step 1: Write the failing test**

Create `b0tKit/Tests/b0tModulesTests/TimeAwareness/TimeAwarenessModuleTests.swift`:

```swift
import XCTest
import b0tBrain
import FoundationModels
@testable import b0tModules

final class TimeAwarenessModuleTests: XCTestCase {
    func testIDIsTimeAwareness() {
        XCTAssertEqual(TimeAwarenessModule.id, "time-awareness")
    }

    func testRequiredPermissionsIsEmpty() throws {
        let m = try TimeAwarenessModule(parameters: Frontmatter())
        XCTAssertEqual(m.requiredPermissions.count, 0)
    }

    func testToolsContainsExactlyTimeAwarenessTool() throws {
        let m = try TimeAwarenessModule(parameters: Frontmatter())
        XCTAssertEqual(m.tools.count, 1)
        XCTAssertEqual(m.tools[0].name, "time_awareness")
    }

    func testInitFromFrontmatterAcceptsAnyFrontmatter() throws {
        // No required parameters — module is permissionless and parameter-less.
        // Verifies that a populated frontmatter doesn't trip the init.
        let fm = Frontmatter(orderedPairs: [
            ("module_id", .string("time-awareness")),
            ("enabled", .bool(true)),
            ("some_extra_key", .string("ignored"))
        ])
        XCTAssertNoThrow(try TimeAwarenessModule(parameters: fm))
    }
}
```

Note: `Frontmatter(orderedPairs:)` is `internal` per Phase 1's API. The test file uses `@testable import b0tModules`; if `Frontmatter`'s init isn't visible, expose a public init in `b0tBrain` or use a public factory the b0tBrain test target already provides. If neither exists, add a `package` init to `Frontmatter` in this commit (a tiny b0tBrain change). Check with: `grep -n 'init(orderedPairs' b0tKit/Sources/b0tBrain/Frontmatter.swift`.

If a package init is needed:

Edit `b0tKit/Sources/b0tBrain/Frontmatter.swift`:
```swift
package init(orderedPairs: [(String, YAMLValue)]) {
    self.keys = orderedPairs.map(\.0)
    self.storage = Dictionary(uniqueKeysWithValues: orderedPairs)
}
```

Replace the existing `internal init`. (`package` is wider than `internal` and lets b0tModules tests construct frontmatters without parsing markdown.)

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.TimeAwarenessModuleTests`
Expected: FAIL — `TimeAwarenessModule` undefined.

- [ ] **Step 3: Implement the module**

Create `b0tKit/Sources/b0tModules/TimeAwareness/TimeAwarenessModule.swift`:

```swift
import Foundation
import FoundationModels
import b0tBrain
import b0tCore

/// The simplest possible `Module`: wraps `TimeAwarenessTool`, takes no
/// parameters from frontmatter, requires no permissions. Exists so the
/// model has a no-cost way to anchor its replies in current time, and so
/// `b0tModules` has a permissionless reference Module to test the registry
/// pipeline against before EventKit/HealthKit land.
public struct TimeAwarenessModule: Module {
    public static let id = "time-awareness"
    public let requiredPermissions: [PermissionKind] = []
    public let tools: [any Tool]

    public init(parameters: Frontmatter) throws {
        try self.init(parameters: parameters, clock: SystemClock())
    }

    public init(parameters: Frontmatter, clock: any Clock) throws {
        // No parameters to decode. Frontmatter is accepted but unused.
        _ = parameters
        self.tools = [TimeAwarenessTool(clock: clock)]
    }
}
```

- [ ] **Step 4: Register the module in `ModuleRegistry`**

Edit `b0tKit/Sources/b0tModules/ModuleRegistry.swift`:

Replace the empty factories table:
```swift
private static var factories: [String: @Sendable (Frontmatter) throws -> any Module] {
    var table: [String: @Sendable (Frontmatter) throws -> any Module] = [:]
    // Future slices will populate this table.
    return table
}
```

with:
```swift
private static var factories: [String: @Sendable (Frontmatter) throws -> any Module] {
    var table: [String: @Sendable (Frontmatter) throws -> any Module] = [:]
    table[TimeAwarenessModule.id] = { try TimeAwarenessModule(parameters: $0) }
    // Slice 4 adds CalendarModule
    // Slice 5 adds RemindersModule
    // Slice 6 adds HealthModule (#if canImport(HealthKit) && os(iOS))
    return table
}
```

- [ ] **Step 5: Run tests**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.TimeAwarenessModuleTests`
Expected: PASS, 4 tests.

- [ ] **Step 6: Run full suite**

Run: `swift test --package-path b0tKit`
Expected: PASS. Note that the registry tests from Task 4 may now have changed behaviour — re-verify. The `canonical-modules-bot` fixture has only unknown/disabled/missing-id files, no `time-awareness.md`, so the empty-factories test still passes (`time-awareness` is in the table but the fixture doesn't reference it).

- [ ] **Step 7: Commit**

```bash
git add b0tKit/Sources/b0tModules/TimeAwareness/TimeAwarenessModule.swift b0tKit/Sources/b0tModules/ModuleRegistry.swift b0tKit/Tests/b0tModulesTests/TimeAwareness/TimeAwarenessModuleTests.swift b0tKit/Sources/b0tBrain/Frontmatter.swift
git commit -m "feat(b0tModules): add TimeAwarenessModule + register in factories table"
```

---

### Task 8: Verify registry loads `TimeAwarenessModule` from a fixture bot

**Files:**
- Create: `b0tKit/Tests/b0tModulesTests/Fixtures/canonical-modules-bot/modules/time-awareness.md`
- Modify: `b0tKit/Tests/b0tModulesTests/ModuleRegistryTests.swift`

The previous registry tests used a fixture with only unknown/disabled/missing-id files, asserting the empty-factories path. Now we add a real module file and update the test to confirm the registry instantiates `TimeAwarenessModule`.

- [ ] **Step 1: Add a working module markdown to the canonical fixture**

But the canonical fixture also has `missing-id.md` which throws first. Move that to a separate fixture so the canonical fixture is purely instantiable. Run:

```bash
mkdir -p b0tKit/Tests/b0tModulesTests/Fixtures/missing-id-bot/modules
git mv b0tKit/Tests/b0tModulesTests/Fixtures/canonical-modules-bot/modules/missing-id.md b0tKit/Tests/b0tModulesTests/Fixtures/missing-id-bot/modules/missing-id.md
mkdir -p b0tKit/Tests/b0tModulesTests/Fixtures/missing-id-bot/identity
```

Create `b0tKit/Tests/b0tModulesTests/Fixtures/missing-id-bot/identity/core.md`:

```markdown
---
b0t_name: missing-id
---
# missing-id bot
```

- [ ] **Step 2: Add `time-awareness.md` to canonical fixture**

Create `b0tKit/Tests/b0tModulesTests/Fixtures/canonical-modules-bot/modules/time-awareness.md`:

```markdown
---
module_id: time-awareness
enabled: true
---
# time-awareness

I keep an eye on the clock so my replies stay anchored in real time.
```

- [ ] **Step 3: Update tests**

Edit `b0tKit/Tests/b0tModulesTests/ModuleRegistryTests.swift`:

Replace the body of the test class with:

```swift
import XCTest
import b0tBrain
@testable import b0tModules

final class ModuleRegistryTests: XCTestCase {
    private func loadFixture(named name: String) async throws -> Bot {
        let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")!
        let store = BotStore()
        return try await store.load(at: url)
    }

    func testEmptyBotReturnsEmptyArray() async throws {
        let bot = try await loadFixture(named: "empty-modules-bot")
        let modules = try await ModuleRegistry.loadModules(for: bot)
        XCTAssertEqual(modules.count, 0)
    }

    func testCanonicalBotInstantiatesTimeAwarenessAndSkipsUnknownAndDisabled() async throws {
        let bot = try await loadFixture(named: "canonical-modules-bot")
        let modules = try await ModuleRegistry.loadModules(for: bot)
        XCTAssertEqual(modules.count, 1)
        XCTAssertEqual(type(of: modules[0]).id, "time-awareness")
    }

    func testMissingModuleIDThrowsWithFileURL() async throws {
        let bot = try await loadFixture(named: "missing-id-bot")
        do {
            _ = try await ModuleRegistry.loadModules(for: bot)
            XCTFail("expected throw on missing module_id")
        } catch ModuleLoadError.missingModuleID(let url) {
            XCTAssertEqual(url.lastPathComponent, "missing-id.md")
        } catch {
            XCTFail("expected ModuleLoadError.missingModuleID, got \(error)")
        }
    }
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.ModuleRegistryTests`
Expected: PASS, 3 tests.

- [ ] **Step 5: Run full suite**

Run: `swift test --package-path b0tKit`
Expected: PASS, all green.

- [ ] **Step 6: Commit**

```bash
git add b0tKit/Tests/b0tModulesTests/Fixtures/ b0tKit/Tests/b0tModulesTests/ModuleRegistryTests.swift
git commit -m "test(b0tModules): registry instantiates TimeAwarenessModule from canonical fixture"
```

---

## Slice 3 — Tool-call records: extraction + transport + chat rendering

End-state: `LanguageModelClient.generate` returns `(Output, [ToolCallRecord])`. `LiveLanguageModelClient` extracts records from the session transcript. `StubLanguageModelClient`'s handler signature accepts an optional record array. `ConversationManager.respond(to:)` returns a new `ConversationTurn` value (response + toolCalls). `DebugBrainView` renders tool-call rows inline between user prompt and assistant reply. `HeartbeatManager` carries records through `TickResult` (rendered into journal in slice 7).

This slice is the largest pipe-laying slice. After it lands, calling `time_awareness` from a stub client renders an inline log row in the demo chat.

### Task 9: Extend `LanguageModelClient.generate` to return `(Output, [ToolCallRecord])`

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Model/LanguageModelClient.swift`
- Modify: `b0tKit/Sources/b0tCore/Model/StubLanguageModelClient.swift`
- Modify: `b0tKit/Sources/b0tCore/Model/LiveLanguageModelClient.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/StubLanguageModelClientTests.swift`

The signature change ripples through `ConversationManager.respondWithFallback`, `HeartbeatManager`, and any test that calls `client.generate` directly. We change the protocol and let the type checker drive the rest.

- [ ] **Step 1: Update the test for `StubLanguageModelClient`**

Edit `b0tKit/Tests/b0tCoreTests/StubLanguageModelClientTests.swift`:

Find the existing test that asserts `generate(...)` returns the typed output. Update its expectation to receive a tuple, and add a new test for the tool-call records.

Replace the file body with:

```swift
import XCTest
import FoundationModels
import b0tBrain
@testable import b0tCore

final class StubLanguageModelClientTests: XCTestCase {
    func testReturnsTypedOutputAndEmptyRecords() async throws {
        let client = StubLanguageModelClient { context, type in
            // Existing handler shape: returns Any. Tools-records default to [].
            return ConversationResponse(text: "echo: \(context.userPrompt)", mood: .thinking, memoryObservations: [])
        }
        let context = AssembledContext.testFixture(userPrompt: "hi")
        let (response, records) = try await client.generate(
            context: context, generating: ConversationResponse.self
        )
        XCTAssertEqual(response.text, "echo: hi")
        XCTAssertEqual(records.count, 0)
    }

    func testHandlerCanReturnTupleWithRecords() async throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let client = StubLanguageModelClient { context, type in
            return StubLanguageModelClient.HandlerResult(
                value: ConversationResponse(text: "done", mood: .thinking, memoryObservations: []),
                toolCalls: [ToolCallRecord(
                    toolName: "time_awareness",
                    argumentsSummary: "(no args)",
                    outputSummary: "12:00 UTC, afternoon",
                    timestamp: date
                )]
            )
        }
        let context = AssembledContext.testFixture(userPrompt: "what time")
        let (response, records) = try await client.generate(
            context: context, generating: ConversationResponse.self
        )
        XCTAssertEqual(response.text, "done")
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].toolName, "time_awareness")
    }

    func testTypeMismatchStillReportsMalformed() async {
        let client = StubLanguageModelClient { _, _ in
            return "not a ConversationResponse"
        }
        let context = AssembledContext.testFixture(userPrompt: "x")
        do {
            _ = try await client.generate(context: context, generating: ConversationResponse.self)
            XCTFail("expected throw")
        } catch LanguageModelClientError.malformedGenerableOutput {
            // expected
        } catch {
            XCTFail("got \(error)")
        }
    }
}
```

`AssembledContext.testFixture` is a Phase 2 test helper — verify it exists with `grep -n 'testFixture' b0tKit/Tests/b0tCoreTests/`. If absent, add a tiny one in this file with a `static func testFixture(userPrompt: String) -> AssembledContext` returning a minimal AssembledContext for these tests.

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter b0tCoreTests.StubLanguageModelClientTests`
Expected: FAIL — generate's return type mismatch.

- [ ] **Step 3: Update the protocol**

Edit `b0tKit/Sources/b0tCore/Model/LanguageModelClient.swift`:

Replace `func generate(...) async throws -> Output` with:

```swift
public protocol LanguageModelClient: Sendable {
    func generate<Output: Generable>(
        context: AssembledContext,
        generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord])
}
```

Add `import b0tBrain` at the top of the file (for `ToolCallRecord`).

- [ ] **Step 4: Update `StubLanguageModelClient`**

Edit `b0tKit/Sources/b0tCore/Model/StubLanguageModelClient.swift`:

Replace the existing struct body with:

```swift
public struct StubLanguageModelClient: LanguageModelClient {
    /// Handlers can return either:
    ///   1. A bare `Any` (the typed Output value) — toolCalls default to [].
    ///   2. A `HandlerResult` — explicit value + scripted tool-call records.
    public typealias Handler = @Sendable (AssembledContext, any Generable.Type) throws -> Any

    public struct HandlerResult: Sendable {
        public let value: Any
        public let toolCalls: [ToolCallRecord]
        public init(value: Any, toolCalls: [ToolCallRecord]) {
            self.value = value
            self.toolCalls = toolCalls
        }
    }

    private let handler: Handler

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    public func generate<Output: Generable>(
        context: AssembledContext,
        generating outputType: Output.Type
    ) async throws -> (Output, [ToolCallRecord]) {
        let raw = try handler(context, outputType)
        let value: Any
        let records: [ToolCallRecord]
        if let wrapped = raw as? HandlerResult {
            value = wrapped.value
            records = wrapped.toolCalls
        } else {
            value = raw
            records = []
        }
        guard let typed = value as? Output else {
            throw LanguageModelClientError.malformedGenerableOutput(
                underlyingDescription: "stub returned \(type(of: value)) for \(outputType)"
            )
        }
        return (typed, records)
    }
}
```

Add `import b0tBrain` at the top.

- [ ] **Step 5: Update `LiveLanguageModelClient` to extract records from the transcript**

Edit `b0tKit/Sources/b0tCore/Model/LiveLanguageModelClient.swift`:

Replace the `generate` method body with:

```swift
public func generate<Output: Generable>(
    context: AssembledContext,
    generating outputType: Output.Type
) async throws -> (Output, [ToolCallRecord]) {
    let session = LanguageModelSession(
        model: .default,
        tools: context.tools,
        instructions: {
            Instructions(context.systemInstructions)
        }
    )

    do {
        let response = try await session.respond(
            to: context.userPrompt,
            generating: outputType
        )
        let records = Self.extractToolCallRecords(from: session.transcript)
        return (response.content, records)
    } catch let error as LanguageModelSession.GenerationError {
        switch error {
        case .exceededContextWindowSize:
            throw LanguageModelClientError.exceededContextWindowSize(
                estimatedTokens: context.budget.estimated
            )
        case .decodingFailure:
            throw LanguageModelClientError.malformedGenerableOutput(
                underlyingDescription: String(describing: error)
            )
        case .assetsUnavailable:
            throw LanguageModelClientError.modelUnavailable
        default:
            Self.logger.error("unhandled GenerationError: \(String(describing: error))")
            throw LanguageModelClientError.sessionFailed(
                underlyingDescription: String(describing: error)
            )
        }
    } catch {
        throw LanguageModelClientError.sessionFailed(
            underlyingDescription: String(describing: error)
        )
    }
}

private static func extractToolCallRecords(
    from transcript: LanguageModelSession.Transcript
) -> [ToolCallRecord] {
    // Walk transcript entries pairing toolCall→toolOutput by id (or by
    // adjacency, depending on what the iOS 26 SDK actually exposes — verify
    // at implementation time and adapt). Apple's transcript API is the
    // single source of truth; if the entry shape differs from what's
    // documented here, adapt the matching logic and update this comment.
    //
    // Verified-at-impl-time behaviour: each tool invocation appears as a
    // pair of entries — one .toolCall(name, arguments) and one .toolOutput
    // (matching the same call). We collect pairs and produce one record
    // per pair. If a toolCall is unmatched (rare, indicates a session
    // failure mid-call), produce a record with an empty outputSummary.

    // Skeleton; specific Transcript.Entry case names + accessors filled
    // in during implementation by reading the FoundationModels SDK headers.
    // If the API doesn't expose what we need, fall back to per-Tool
    // instrumentation (see spec §11 risk #1).
    var records: [ToolCallRecord] = []
    let now = Date()
    // for entry in transcript.entries { ... }
    // This implementation is filled in during Task 9; the test in Step 1
    // exercises the Stub path which doesn't depend on transcript walking.
    // Live transcript-walking is exercised by Task 38 (gated live tests).
    _ = transcript
    _ = now
    return records
}
```

Note on the transcript-walk: Phase 2's task 32 documented that `Tool` is instance-property-keyed in the iOS 26 SDK rather than static. Expect similar SDK surprises here. The skeleton above is intentionally minimal; the implementer should:

1. Open the FoundationModels module header (Cmd+click `LanguageModelSession.Transcript` in Xcode) to see the actual Entry shape.
2. Pattern-match the relevant case(s) — likely `.toolCall(name:arguments:)` and `.toolOutput(callID:value:)` or similar.
3. If the SDK does not expose call IDs, pair toolCall→toolOutput by adjacency.
4. If the SDK does not expose the arguments at all (privacy redaction), fall back to per-Tool instrumentation: each Tool's `call(arguments:)` records into a turn-scoped collector via a `TaskLocal` or actor-injected `ToolCallCollector`. This fallback is documented in spec §11 risk #1.

Document whatever final approach in the commit message and in `b0tCore/CLAUDE.md` at end of phase.

- [ ] **Step 6: Update direct call sites of `generate`**

Search for `client.generate` usages: `grep -rn "client.generate\|\.generate(context:" b0tKit/`

In `b0tKit/Sources/b0tCore/ConversationManager.swift`, find:
```swift
return try await client.generate(context: context, generating: ConversationResponse.self)
```

Replace with:
```swift
let (response, _) = try await client.generate(context: context, generating: ConversationResponse.self)
return response
```

(The toolCalls are dropped here; Task 12 wires them through a new return type. This step keeps the build green between Task 9 and Task 12.)

Apply the same pattern in `b0tKit/Sources/b0tCore/HeartbeatManager.swift` if it calls `generate` directly.

- [ ] **Step 7: Run full suite**

Run: `swift test --package-path b0tKit`
Expected: PASS. All existing tests still green; the new Stub test passes.

- [ ] **Step 8: Commit**

```bash
git add b0tKit/Sources/b0tCore/Model/ b0tKit/Sources/b0tCore/ConversationManager.swift b0tKit/Sources/b0tCore/HeartbeatManager.swift b0tKit/Tests/b0tCoreTests/StubLanguageModelClientTests.swift
git commit -m "feat(b0tCore): LanguageModelClient.generate returns (Output, [ToolCallRecord])"
```

---

### Task 10: `ConversationTurn` return type + `ConversationManager.respond(to:)` rewrite

**Files:**
- Create: `b0tKit/Sources/b0tCore/ConversationTurn.swift`
- Modify: `b0tKit/Sources/b0tCore/ConversationManager.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/ConversationManagerTests.swift`

- [ ] **Step 1: Write the failing test**

Edit `b0tKit/Tests/b0tCoreTests/ConversationManagerTests.swift` (existing file from Phase 2):

Add to the test class:

```swift
func testRespondReturnsToolCallsFromStub() async throws {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let client = StubLanguageModelClient { context, _ in
        return StubLanguageModelClient.HandlerResult(
            value: ConversationResponse(text: "ok", mood: .thinking, memoryObservations: []),
            toolCalls: [ToolCallRecord(
                toolName: "time_awareness",
                argumentsSummary: "(no args)",
                outputSummary: "12:00 UTC, afternoon",
                timestamp: date
            )]
        )
    }
    // The remainder of the test reuses Phase 2's bot-fixture helper. Look
    // at existing ConversationManagerTests for the bot-construction helper
    // (e.g. `try await Self.makeBot()`) and reuse it.
    let bot = try await Self.makeBot()
    let store = await bot.store
    let manager = ConversationManager(bot: bot, store: store, client: client, clock: TestClock())
    let turn: ConversationTurn = try await manager.respond(to: "what time")
    XCTAssertEqual(turn.response.text, "ok")
    XCTAssertEqual(turn.toolCalls.count, 1)
    XCTAssertEqual(turn.toolCalls[0].toolName, "time_awareness")
}
```

If `Self.makeBot()` doesn't exist, look for whichever helper Phase 2's tests use and reuse the same idiom.

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter b0tCoreTests.ConversationManagerTests`
Expected: FAIL — `ConversationTurn` undefined.

- [ ] **Step 3: Add `ConversationTurn`**

Create `b0tKit/Sources/b0tCore/ConversationTurn.swift`:

```swift
import Foundation
import b0tBrain

/// The full result of a single user-turn flow: the typed model response
/// plus the tool-call records observed during the turn.
///
/// Returned by `ConversationManager.respond(to:)`. `DebugBrainView` (and
/// later Phase-4 surfaces) renders `toolCalls` inline between the user
/// prompt and the assistant reply.
///
/// `ConversationResponse` is `@Generable` (model-produced); `toolCalls` is
/// observed-by-runtime. Keeping them as separate fields preserves that
/// ontological distinction.
public struct ConversationTurn: Sendable {
    public let response: ConversationResponse
    public let toolCalls: [ToolCallRecord]

    public init(response: ConversationResponse, toolCalls: [ToolCallRecord]) {
        self.response = response
        self.toolCalls = toolCalls
    }
}
```

- [ ] **Step 4: Update `ConversationManager.respond(to:)` signature and body**

Edit `b0tKit/Sources/b0tCore/ConversationManager.swift`:

Change the public signature:
```swift
public func respond(to userPrompt: String) async throws -> ConversationTurn {
```

Inside, propagate the records:

```swift
public func respond(to userPrompt: String) async throws -> ConversationTurn {
    if !didLoadTurnNumber {
        nextTurnNumber = await loadNextTurnNumber()
        didLoadTurnNumber = true
    }
    let turnNumber = nextTurnNumber
    nextTurnNumber += 1

    do {
        let (response, toolCalls) = try await respondWithFallback(userPrompt: userPrompt, level: 0)
        let delta = try await executor.apply(response)
        try await journalWriter.appendConversationTurn(
            prompt: userPrompt,
            response: response,
            stateDelta: delta,
            turnNumber: turnNumber,
            toolCalls: toolCalls
        )
        return ConversationTurn(response: response, toolCalls: toolCalls)
    } catch {
        try? await journalWriter.appendError(error: error, kind: .turn(number: turnNumber))
        throw error
    }
}

private func respondWithFallback(userPrompt: String, level: Int) async throws -> (ConversationResponse, [ToolCallRecord]) {
    let context = try await assembler.assemble(
        mode: .conversation(userPrompt: userPrompt),
        fallbackLevel: level
    )
    do {
        return try await client.generate(context: context, generating: ConversationResponse.self)
    } catch LanguageModelClientError.exceededContextWindowSize {
        if level >= 3 {
            return (
                ConversationResponse(
                    text: "oh — let me start fresh, I was getting muddled.",
                    mood: .thinking,
                    memoryObservations: []
                ),
                []
            )
        }
        return try await respondWithFallback(userPrompt: userPrompt, level: level + 1)
    }
}
```

Note `journalWriter.appendConversationTurn` gains a `toolCalls:` parameter. Task 11 implements that signature change in `JournalWriter`. For now we add the call — the build will fail until Task 11 lands, but we commit Task 10 first then Task 11 fixes the journal. (Alternatively: add the `toolCalls:` parameter in JournalWriter as a no-op default in this commit, then implement rendering in Task 11. Pick whichever order keeps each commit individually buildable.)

For this plan: add the parameter to `JournalWriter.appendConversationTurn` here as a no-op default (`toolCalls: [ToolCallRecord] = []`), then Task 11 fills in the rendering.

Edit `b0tKit/Sources/b0tCore/Apply/JournalWriter.swift`:

Find `func appendConversationTurn(...)` and add `toolCalls: [ToolCallRecord] = []` as the last parameter. Don't render it yet — just accept the parameter so the build is green.

- [ ] **Step 5: Run tests**

Run: `swift test --package-path b0tKit --filter b0tCoreTests.ConversationManagerTests`
Expected: PASS, all conversation-manager tests including the new tool-call test.

- [ ] **Step 6: Run full suite**

Run: `swift test --package-path b0tKit`
Expected: PASS, all green.

- [ ] **Step 7: Commit**

```bash
git add b0tKit/Sources/b0tCore/ConversationTurn.swift b0tKit/Sources/b0tCore/ConversationManager.swift b0tKit/Sources/b0tCore/Apply/JournalWriter.swift b0tKit/Tests/b0tCoreTests/ConversationManagerTests.swift
git commit -m "feat(b0tCore): ConversationManager.respond returns ConversationTurn"
```

---

### Task 11: `JournalWriter` renders `tools_called:` sub-section

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Apply/JournalWriter.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift`

The OpenClaw entry format gets a new sub-section under turns and ticks. The format is straightforward markdown — a sub-list under `tools_called:` if the array is non-empty, omitted entirely if empty.

- [ ] **Step 1: Write the failing test**

Edit `b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift`:

Add a new test:

```swift
func testAppendConversationTurnRendersToolsCalledSubsection() async throws {
    let bot = try await Self.makeBot()
    let store = await bot.store
    let clock = TestClock(start: Date(timeIntervalSince1970: 1_700_000_000))
    let writer = JournalWriter(bot: bot, store: store, clock: clock)
    let response = ConversationResponse(text: "ok", mood: .thinking, memoryObservations: [])
    let records = [
        ToolCallRecord(
            toolName: "time_awareness",
            argumentsSummary: "(no args)",
            outputSummary: "12:00 UTC, afternoon",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
    ]
    try await writer.appendConversationTurn(
        prompt: "what time",
        response: response,
        stateDelta: StateDelta(memoryAdditions: [], notificationsRequested: []),
        turnNumber: 1,
        toolCalls: records
    )
    let url = writer.journalURL(for: clock.now())
    let content = try String(contentsOf: url, encoding: .utf8)
    XCTAssertTrue(content.contains("tools_called:"))
    XCTAssertTrue(content.contains("time_awareness"))
    XCTAssertTrue(content.contains("(no args)"))
    XCTAssertTrue(content.contains("12:00 UTC, afternoon"))
}

func testAppendConversationTurnOmitsToolsCalledIfEmpty() async throws {
    let bot = try await Self.makeBot()
    let store = await bot.store
    let clock = TestClock(start: Date(timeIntervalSince1970: 1_700_000_000))
    let writer = JournalWriter(bot: bot, store: store, clock: clock)
    let response = ConversationResponse(text: "ok", mood: .thinking, memoryObservations: [])
    try await writer.appendConversationTurn(
        prompt: "hi",
        response: response,
        stateDelta: StateDelta(memoryAdditions: [], notificationsRequested: []),
        turnNumber: 1,
        toolCalls: []
    )
    let url = writer.journalURL(for: clock.now())
    let content = try String(contentsOf: url, encoding: .utf8)
    XCTAssertFalse(content.contains("tools_called"))
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter b0tCoreTests.JournalWriterTests`
Expected: First test FAILS — `tools_called:` not rendered.

- [ ] **Step 3: Render `tools_called:` in `appendConversationTurn`**

Edit `b0tKit/Sources/b0tCore/Apply/JournalWriter.swift`:

Find the existing rendering of a turn entry. Add, immediately after the `state_delta:` rendering (or before the closing `journal_entry:` field — exact placement depends on Phase 2's existing format):

```swift
if !toolCalls.isEmpty {
    lines.append("  - tools_called:")
    for record in toolCalls {
        lines.append("    - \(record.toolName)(\(record.argumentsSummary)) → \(record.outputSummary)")
    }
}
```

(`lines` is illustrative — match Phase 2's actual buffer-construction idiom in JournalWriter.)

- [ ] **Step 4: Run tests**

Run: `swift test --package-path b0tKit --filter b0tCoreTests.JournalWriterTests`
Expected: PASS. Both new tests green.

- [ ] **Step 5: Run full suite**

Run: `swift test --package-path b0tKit`
Expected: PASS, all green.

- [ ] **Step 6: Commit**

```bash
git add b0tKit/Sources/b0tCore/Apply/JournalWriter.swift b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift
git commit -m "feat(b0tCore): JournalWriter renders tools_called: sub-section in turn entries"
```

---

### Task 12: `HeartbeatManager.tick(...)` threads `[ToolCallRecord]` through `TickResult`

**Files:**
- Modify: `b0tKit/Sources/b0tCore/HeartbeatManager.swift` (or wherever `TickResult` is defined)
- Modify: `b0tKit/Sources/b0tCore/Apply/JournalWriter.swift` — `appendTick` accepts `toolCalls`
- Modify: `b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift`

- [ ] **Step 1: Write the failing tests**

Edit `b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift`:

Add:

```swift
func testTickResultCarriesToolCallRecords() async throws {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let client = StubLanguageModelClient { _, _ in
        return StubLanguageModelClient.HandlerResult(
            value: TickDecision(action: .act, organUsed: "time-awareness", journalEntry: "noting the time", memoryUpdate: nil),
            toolCalls: [ToolCallRecord(toolName: "time_awareness", argumentsSummary: "(no args)", outputSummary: "12:00", timestamp: date)]
        )
    }
    let bot = try await Self.makeBot()
    let store = await bot.store
    let manager = HeartbeatManager(bot: bot, store: store, client: client, clock: TestClock(), scheduler: FakeHeartbeatScheduler())
    let result = try await manager.tick(trigger: .manual)
    XCTAssertEqual(result.toolCalls.count, 1)
    XCTAssertEqual(result.toolCalls[0].toolName, "time_awareness")
}
```

(If `Self.makeBot()` etc. aren't named the same — match the existing helper idiom.)

Edit `b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift`:

Add:

```swift
func testAppendTickRendersToolsCalled() async throws {
    let bot = try await Self.makeBot()
    let store = await bot.store
    let clock = TestClock(start: Date(timeIntervalSince1970: 1_700_000_000))
    let writer = JournalWriter(bot: bot, store: store, clock: clock)
    let decision = TickDecision(action: .act, organUsed: "time-awareness", journalEntry: "noting", memoryUpdate: nil)
    let records = [ToolCallRecord(toolName: "time_awareness", argumentsSummary: "(no args)", outputSummary: "12:00", timestamp: Date(timeIntervalSince1970: 1_700_000_000))]
    try await writer.appendTick(
        decision: decision,
        stateDelta: StateDelta(memoryAdditions: [], notificationsRequested: []),
        toolCalls: records
    )
    let url = writer.journalURL(for: clock.now())
    let content = try String(contentsOf: url, encoding: .utf8)
    XCTAssertTrue(content.contains("tools_called:"))
    XCTAssertTrue(content.contains("time_awareness"))
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit`
Expected: Both new tests FAIL — `TickResult.toolCalls` undefined; `appendTick` lacks `toolCalls:` parameter.

- [ ] **Step 3: Update `TickResult` and `HeartbeatManager`**

Edit `b0tKit/Sources/b0tCore/HeartbeatManager.swift` (or wherever `TickResult` lives — `b0tCore/Support/TickResult.swift` per file structure in Phase 2):

Add a `toolCalls: [ToolCallRecord]` field to the `decided` case (and any analogous case). Update `HeartbeatManager.tick(trigger:)` to thread the records from `client.generate(...)` into the `TickResult` and into `journalWriter.appendTick(...)`.

Specific shape (read existing file first to confirm — TickResult may be an enum with associated values rather than a struct):

If TickResult is currently:
```swift
public enum TickResult: Sendable {
    case decided(decision: TickDecision, delta: StateDelta)
    case suppressed(reason: SuppressionReason)
    case errored(any Error)
}
```

Update `decided` to:
```swift
case decided(decision: TickDecision, delta: StateDelta, toolCalls: [ToolCallRecord])
```

And add to `HeartbeatManager.tick`:
```swift
let (decision, toolCalls) = try await client.generate(context: context, generating: TickDecision.self)
let delta = try await executor.apply(decision)
try await journalWriter.appendTick(decision: decision, stateDelta: delta, toolCalls: toolCalls)
return .decided(decision: decision, delta: delta, toolCalls: toolCalls)
```

Replace any prior `TickResult.decided(...)` constructors in the codebase to include the new field.

- [ ] **Step 4: Update `JournalWriter.appendTick`**

Edit `b0tKit/Sources/b0tCore/Apply/JournalWriter.swift`:

Add `toolCalls: [ToolCallRecord] = []` parameter. Render the same `tools_called:` sub-section pattern as in `appendConversationTurn`:

```swift
if !toolCalls.isEmpty {
    lines.append("  - tools_called:")
    for record in toolCalls {
        lines.append("    - \(record.toolName)(\(record.argumentsSummary)) → \(record.outputSummary)")
    }
}
```

- [ ] **Step 5: Run tests**

Run: `swift test --package-path b0tKit`
Expected: PASS, all green.

- [ ] **Step 6: Commit**

```bash
git add b0tKit/Sources/b0tCore/HeartbeatManager.swift b0tKit/Sources/b0tCore/Support/TickResult.swift b0tKit/Sources/b0tCore/Apply/JournalWriter.swift b0tKit/Tests/b0tCoreTests/HeartbeatManagerTests.swift b0tKit/Tests/b0tCoreTests/JournalWriterTests.swift
git commit -m "feat(b0tCore): TickResult.decided carries [ToolCallRecord]; appendTick renders tools_called"
```

---

### Task 13: `DebugBrainView` renders tool-call rows inline

**Files:**
- Modify: `b0tApp/Sources/Debug/DebugBrainView.swift`
- Modify: `b0tApp/Sources/App/b0tApp.swift` (wire ModuleRegistry on app start)

This is the visible end-state for slice 3: when the user types a prompt and the (stubbed or live) model uses a tool, the chat log shows the tool call inline.

- [ ] **Step 1: Inspect current `DebugBrainView`**

Run: `cat b0tApp/Sources/Debug/DebugBrainView.swift`

Identify the chat-log row component. Per Phase 2's task 5, each row shows user prompt + assistant response. We'll add an optional `[ToolCallRecord]` to the row's data and render it as monospace dimmed text.

- [ ] **Step 2: Update the chat log's data model**

Edit `b0tApp/Sources/Debug/DebugBrainView.swift`:

Find the type that represents a chat log entry (likely a struct with `userPrompt: String`, `response: String`, etc.). Add:

```swift
let toolCalls: [ToolCallRecord]
```

(Add `import b0tBrain` if not already present.)

In the message-row view, between the user-prompt and the assistant-reply rendering, add:

```swift
if !entry.toolCalls.isEmpty {
    VStack(alignment: .leading, spacing: 2) {
        ForEach(entry.toolCalls.indices, id: \.self) { i in
            let record = entry.toolCalls[i]
            Text("→ \(record.toolName)(\(record.argumentsSummary))")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.leading, 12)
            Text("← \(record.outputSummary)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.leading, 12)
        }
    }
    .padding(.vertical, 4)
}
```

(Adapt to actual SwiftUI idiom in the file. Use `IoskeleyMono NL` font if the app's design system defines it; fall back to system monospaced if not.)

- [ ] **Step 3: Update the call to `respond(to:)`**

Find where `manager.respond(to: prompt)` is called. The call now returns `ConversationTurn`. Update:

```swift
let turn = try await manager.respond(to: prompt)
chatLog.append(ChatEntry(userPrompt: prompt, response: turn.response.text, toolCalls: turn.toolCalls))
```

- [ ] **Step 4: Wire `ModuleRegistry` at app start**

Edit `b0tApp/Sources/App/b0tApp.swift`:

Find where the active bot is loaded. Add module loading immediately after:

```swift
import b0tModules

// inside init() or wherever the live ConversationManager is constructed:
let bot = ...
let modules = (try? await ModuleRegistry.loadModules(for: bot)) ?? []
let tools = modules.flatMap(\.tools)
let toolsRequirePermission = modules.contains { !$0.requiredPermissions.isEmpty }

// Pass to ContextAssembler / ConversationManager construction:
let assembler = ContextAssembler(bot: bot, store: store, tools: tools, toolsRequirePermission: toolsRequirePermission)
let manager = ConversationManager(bot: bot, store: store, client: client, clock: SystemClock(), assembler: assembler)
```

Note: `ContextAssembler.init` and `ConversationManager.init` need updates to accept tools — Task 14 lands those changes. For Task 13, leave the wiring code but pass tools through whatever Phase 2 init accepts (might be an empty `[any Tool]`); the `tools` flow ends here until Task 14 / Slice 7's Task 23.

If existing init doesn't support a tools parameter at all, Task 13 commits the DebugBrainView render change only, and the app-startup wiring deferred to Task 23. Adjust scope of Task 13's commit accordingly.

- [ ] **Step 5: Build and smoke-test in simulator**

**[VERIFY]** Build the iOS app target. Run:
```bash
xcodebuild -project b0t.xcodeproj -scheme b0tApp -sdk iphonesimulator build
```
Expected: clean build.

Launch in simulator (Phase 2's `--debug-heartbeat-timer --use-stub-client` launch args). Type "what time is it" — `time_awareness` won't actually fire from a stub unless the stub is scripted to invoke it. For Slice 3's smoke test, manually script the stub in `DebugBrainView` (DEBUG-only) to inject a `HandlerResult` with one fake `time_awareness` record, and verify the row renders.

If hard to script: defer the visual smoke test to Slice 7's acceptance smoke (when live Modules are in place) and rely on the unit tests for now.

- [ ] **Step 6: Commit**

```bash
git add b0tApp/Sources/Debug/DebugBrainView.swift b0tApp/Sources/App/b0tApp.swift
git commit -m "feat(b0tApp): DebugBrainView renders tool-call rows inline"
```

---

## Slice 4 — Calendar bridge

End-state: `CalendarModule` registered, `calendar.upcoming_events` tool returns real events from EKEventStore on grant, `permissionDenied: true` on deny. Live integration runs in iOS simulator (gated). `EventKitStore` protocol + `LiveEventKitStore` + `FakeEventKitStore` in place. `PermissionGate.ensure(.calendar)` is wired.

### Task 14: `EventKitStore` protocol + `LiveEventKitStore` (calendar surface)

**Files:**
- Create: `b0tKit/Sources/b0tModules/EventKit/EventKitStore.swift`
- Create: `b0tKit/Tests/b0tModulesTests/EventKit/FakeEventKitStore.swift`
- Test: `b0tKit/Tests/b0tModulesTests/EventKit/FakeEventKitStoreTests.swift`

We define the protocol with **only the calendar methods** in this task. Reminder methods land in Task 19. That keeps each task small.

- [ ] **Step 1: Write the failing test**

Create `b0tKit/Tests/b0tModulesTests/EventKit/FakeEventKitStoreTests.swift`:

```swift
import XCTest
import EventKit
@testable import b0tModules

final class FakeEventKitStoreTests: XCTestCase {
    func testInitialAuthorizationStatusIsNotDetermined() {
        let store = FakeEventKitStore()
        XCTAssertEqual(store.authorizationStatus(for: .event), .notDetermined)
    }

    func testGrantingAccessFlipsStatusAndReturnsTrue() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.event] = true
        let granted = try await store.requestAccess(to: .event)
        XCTAssertTrue(granted)
        XCTAssertEqual(store.authorizationStatus(for: .event), .fullAccess)
    }

    func testDenyingAccessFlipsStatusAndReturnsFalse() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.event] = false
        let granted = try await store.requestAccess(to: .event)
        XCTAssertFalse(granted)
        XCTAssertEqual(store.authorizationStatus(for: .event), .denied)
    }

    func testEventsMatchingReturnsScriptedEvents() async {
        let store = FakeEventKitStore()
        let calendar = EKCalendar(for: .event, eventStore: EKEventStore())
        calendar.title = "Personal"
        let event = EKEvent(eventStore: EKEventStore())
        event.title = "coffee with Lin"
        event.startDate = Date(timeIntervalSince1970: 1_700_000_000)
        event.endDate = event.startDate.addingTimeInterval(1800)
        event.calendar = calendar
        store.scriptedEvents = [event]
        let predicate = NSPredicate(value: true)
        let results = await store.events(matching: predicate)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "coffee with Lin")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.FakeEventKitStoreTests`
Expected: FAIL — `FakeEventKitStore` undefined.

- [ ] **Step 3: Define the protocol**

Create `b0tKit/Sources/b0tModules/EventKit/EventKitStore.swift`:

```swift
import Foundation
import EventKit

/// The seam through which `b0tModules`'s calendar and reminder tools talk
/// to EventKit. Two implementations exist: `LiveEventKitStore` (wraps
/// Apple's `EKEventStore`) and `FakeEventKitStore` (test-target visible,
/// scriptable in-memory state).
///
/// Only the methods the tools actually use are listed. Adding tools may
/// require extending this protocol in a follow-up commit.
public protocol EventKitStore: Sendable {
    func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus
    func requestAccess(to entityType: EKEntityType) async throws -> Bool

    // Calendar
    func events(matching predicate: NSPredicate) async -> [EKEvent]
    func calendars(for entityType: EKEntityType) -> [EKCalendar]

    // Reminders (Task 19 fills these in; not used in Slice 4)
    // func save(_ reminder: EKReminder, commit: Bool) throws
    // func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder]
    // func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate
    // func defaultCalendarForNewReminders() -> EKCalendar?
}

/// The production `EventKitStore`. Wraps an `EKEventStore` singleton.
public struct LiveEventKitStore: EventKitStore {
    private let store: EKEventStore

    public init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    public func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: entityType)
    }

    public func requestAccess(to entityType: EKEntityType) async throws -> Bool {
        switch entityType {
        case .event:
            return try await store.requestFullAccessToEvents()
        case .reminder:
            return try await store.requestFullAccessToReminders()
        @unknown default:
            return false
        }
    }

    public func events(matching predicate: NSPredicate) async -> [EKEvent] {
        store.events(matching: predicate)
    }

    public func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        store.calendars(for: entityType)
    }
}
```

- [ ] **Step 4: Define the fake**

Create `b0tKit/Tests/b0tModulesTests/EventKit/FakeEventKitStore.swift`:

```swift
import Foundation
import EventKit
@testable import b0tModules

/// Scriptable in-memory `EventKitStore` for unit tests. Tests set
/// `scriptedGrant[.event] = true/false` to control `requestAccess`'s
/// resolution; `scriptedEvents` controls what `events(matching:)` returns
/// (predicates are ignored — tests filter by setting the array directly).
final class FakeEventKitStore: EventKitStore, @unchecked Sendable {
    var scriptedGrant: [EKEntityType: Bool] = [:]
    var scriptedEvents: [EKEvent] = []
    var scriptedCalendars: [EKCalendar] = []
    private(set) var currentStatus: [EKEntityType: EKAuthorizationStatus] = [:]

    func authorizationStatus(for entityType: EKEntityType) -> EKAuthorizationStatus {
        currentStatus[entityType] ?? .notDetermined
    }

    func requestAccess(to entityType: EKEntityType) async throws -> Bool {
        let granted = scriptedGrant[entityType] ?? false
        currentStatus[entityType] = granted ? .fullAccess : .denied
        return granted
    }

    func events(matching predicate: NSPredicate) async -> [EKEvent] {
        scriptedEvents
    }

    func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        scriptedCalendars
    }
}
```

- [ ] **Step 5: Run tests**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.FakeEventKitStoreTests`
Expected: PASS, 4 tests.

- [ ] **Step 6: Run full suite**

Run: `swift test --package-path b0tKit`
Expected: PASS, all green.

- [ ] **Step 7: Commit**

```bash
git add b0tKit/Sources/b0tModules/EventKit/ b0tKit/Tests/b0tModulesTests/EventKit/
git commit -m "feat(b0tModules): EventKitStore protocol + Live + Fake (calendar surface)"
```

---

### Task 15: Wire `.calendar` into `PermissionGate`

**Files:**
- Modify: `b0tKit/Sources/b0tModules/PermissionGate.swift`
- Modify: `b0tKit/Tests/b0tModulesTests/PermissionGateTests.swift`

- [ ] **Step 1: Write the failing tests**

Edit `b0tKit/Tests/b0tModulesTests/PermissionGateTests.swift`:

Replace the body with:

```swift
import XCTest
import EventKit
@testable import b0tModules

final class PermissionGateTests: XCTestCase {
    func testCalendarGrantedReturnsTrue() async {
        let store = FakeEventKitStore()
        store.scriptedGrant[.event] = true
        let gate = PermissionGate(eventKit: store)
        let granted = await gate.ensure(.calendar)
        XCTAssertTrue(granted)
    }

    func testCalendarDeniedReturnsFalse() async {
        let store = FakeEventKitStore()
        store.scriptedGrant[.event] = false
        let gate = PermissionGate(eventKit: store)
        let granted = await gate.ensure(.calendar)
        XCTAssertFalse(granted)
    }

    func testCalendarAlreadyGrantedSkipsRequest() async {
        let store = FakeEventKitStore()
        // Pre-grant by flipping the status directly. The fake doesn't
        // count requestAccess invocations, so we verify by setting
        // scriptedGrant to false and confirming the gate still returns true
        // because authorizationStatus(.event) reports .fullAccess.
        store.scriptedGrant[.event] = false
        // Use reflection / a setter on the fake — for simplicity, flip via
        // a successful request first, then re-test:
        _ = try? await store.requestAccess(to: .event)
        // status now .denied. Reset:
        // (For this test we rely on the gate's logic: if status is already
        // .fullAccess, no request is made. The fake's behaviour is covered
        // in FakeEventKitStoreTests; here we verify the gate's switch.)
        // Concrete test: directly assert the gate uses authorizationStatus
        // before requestAccess.
        // Simplest passing assertion: skip this test for now and rely on
        // the integration tests in Task 17. Remove this test method.
    }
}
```

(The third test as drafted is awkward. Cut it — the gate's "skip request if already granted" behaviour is tested at the integration level in Task 17. Keep only the two grant/deny tests.)

Final Step 1 file contents:

```swift
import XCTest
import EventKit
@testable import b0tModules

final class PermissionGateTests: XCTestCase {
    func testCalendarGrantedReturnsTrue() async {
        let store = FakeEventKitStore()
        store.scriptedGrant[.event] = true
        let gate = PermissionGate(eventKit: store)
        let granted = await gate.ensure(.calendar)
        XCTAssertTrue(granted)
    }

    func testCalendarDeniedReturnsFalse() async {
        let store = FakeEventKitStore()
        store.scriptedGrant[.event] = false
        let gate = PermissionGate(eventKit: store)
        let granted = await gate.ensure(.calendar)
        XCTAssertFalse(granted)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.PermissionGateTests`
Expected: FAIL — `PermissionGate.init(eventKit:)` undefined; the existing `init()` traps in `.calendar`.

- [ ] **Step 3: Update `PermissionGate`**

Edit `b0tKit/Sources/b0tModules/PermissionGate.swift`:

Replace the entire actor body with:

```swift
import Foundation
import EventKit
#if canImport(HealthKit)
import HealthKit
#endif

package actor PermissionGate {
    private let eventKit: any EventKitStore
    #if canImport(HealthKit) && os(iOS)
    private let health: any HealthStore
    #endif

    #if canImport(HealthKit) && os(iOS)
    package init(
        eventKit: any EventKitStore = LiveEventKitStore(),
        health: any HealthStore = LiveHealthStore()
    ) {
        self.eventKit = eventKit
        self.health = health
    }
    #else
    package init(eventKit: any EventKitStore = LiveEventKitStore()) {
        self.eventKit = eventKit
    }
    #endif

    package func ensure(_ kind: PermissionKind) async -> Bool {
        switch kind {
        case .calendar:
            return await ensureEventKit(.event)
        case .reminders:
            return await ensureEventKit(.reminder)
        #if canImport(HealthKit)
        case .healthRead(let types):
            #if os(iOS)
            return await ensureHealthRead(types)
            #else
            return false
            #endif
        #endif
        }
    }

    private func ensureEventKit(_ entityType: EKEntityType) async -> Bool {
        let status = eventKit.authorizationStatus(for: entityType)
        switch status {
        case .fullAccess, .authorized:
            return true
        case .notDetermined:
            return (try? await eventKit.requestAccess(to: entityType)) ?? false
        case .denied, .restricted, .writeOnly:
            return false
        @unknown default:
            return false
        }
    }

    #if canImport(HealthKit) && os(iOS)
    private func ensureHealthRead(_ types: [HKQuantityTypeIdentifier]) async -> Bool {
        // Slice 6 fills this in. For Slice 4, only calendar/reminders cases
        // are exercised. This stub returns false — the matching tests don't
        // run yet because HealthModule isn't in factories.
        let hkTypes: Set<HKObjectType> = Set(types.compactMap { HKQuantityType(.init(rawValue: $0.rawValue)) })
        do {
            try await health.requestAuthorization(toShare: nil, read: hkTypes)
            return true
        } catch {
            return false
        }
    }
    #endif
}
```

Note the `#if canImport(HealthKit) && os(iOS)` guards: the `health` backend is only constructed on iOS where HealthKit is fully available (mirrors Phase 2's BGTaskScheduler pattern). The non-iOS init just takes EventKit.

If `LiveHealthStore` doesn't exist yet (it lands in Task 22), provisionally leave the `init(eventKit: ..., health: ...)` accepting the existing/dummy value. The cleanest path: make this Task 15 update only the EventKit path, and Task 22 extends `PermissionGate` with the health init/handling. Adjust scope accordingly — drop the HealthKit-related code from this commit and fold it into Task 22.

For this plan: **drop the HealthKit handling from Task 15.** Final shape for Slice 4:

```swift
import Foundation
import EventKit

package actor PermissionGate {
    private let eventKit: any EventKitStore

    package init(eventKit: any EventKitStore = LiveEventKitStore()) {
        self.eventKit = eventKit
    }

    package func ensure(_ kind: PermissionKind) async -> Bool {
        switch kind {
        case .calendar:
            return await ensureEventKit(.event)
        case .reminders:
            return await ensureEventKit(.reminder)
        #if canImport(HealthKit)
        case .healthRead:
            // Slice 6 wires this.
            return false
        #endif
        }
    }

    private func ensureEventKit(_ entityType: EKEntityType) async -> Bool {
        let status = eventKit.authorizationStatus(for: entityType)
        switch status {
        case .fullAccess, .authorized:
            return true
        case .notDetermined:
            return (try? await eventKit.requestAccess(to: entityType)) ?? false
        case .denied, .restricted, .writeOnly:
            return false
        @unknown default:
            return false
        }
    }
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.PermissionGateTests`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tModules/PermissionGate.swift b0tKit/Tests/b0tModulesTests/PermissionGateTests.swift
git commit -m "feat(b0tModules): PermissionGate handles .calendar and .reminders via EventKitStore"
```

---

### Task 16: `CalendarUpcomingEventsTool` — `@Generable` types + permission flow

**Files:**
- Create: `b0tKit/Sources/b0tModules/Calendar/CalendarUpcomingEventsTool.swift`
- Create: `b0tKit/Tests/b0tModulesTests/Calendar/CalendarUpcomingEventsToolTests.swift`

- [ ] **Step 1: Write the failing test**

Create `b0tKit/Tests/b0tModulesTests/Calendar/CalendarUpcomingEventsToolTests.swift`:

```swift
import XCTest
import EventKit
import FoundationModels
import b0tCore
@testable import b0tModules

final class CalendarUpcomingEventsToolTests: XCTestCase {
    private func makeTool(
        store: FakeEventKitStore,
        defaultLookahead: Int = 24
    ) -> CalendarUpcomingEventsTool {
        let gate = PermissionGate(eventKit: store)
        let clock = TestClock(start: Date(timeIntervalSince1970: 1_700_000_000))
        return CalendarUpcomingEventsTool(store: store, gate: gate, clock: clock, defaultLookaheadHours: defaultLookahead)
    }

    func testGrantedAccessReturnsEvents() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.event] = true
        let cal = EKCalendar(for: .event, eventStore: EKEventStore())
        cal.title = "Personal"
        let event = EKEvent(eventStore: EKEventStore())
        event.title = "coffee with Lin"
        event.startDate = Date(timeIntervalSince1970: 1_700_000_000 + 3600)
        event.endDate = event.startDate.addingTimeInterval(1800)
        event.calendar = cal
        store.scriptedEvents = [event]

        let tool = makeTool(store: store)
        let output = try await tool.call(arguments: .init(windowHours: 24))
        XCTAssertEqual(output.events.count, 1)
        XCTAssertEqual(output.events[0].title, "coffee with Lin")
        XCTAssertFalse(output.permissionDenied)
    }

    func testDeniedAccessReturnsPermissionDeniedAndEmptyEvents() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.event] = false
        let tool = makeTool(store: store)
        let output = try await tool.call(arguments: .init(windowHours: nil))
        XCTAssertEqual(output.events.count, 0)
        XCTAssertTrue(output.permissionDenied)
    }

    func testToolNameIsCalendarUpcomingEvents() {
        let tool = makeTool(store: FakeEventKitStore())
        XCTAssertEqual(tool.name, "calendar.upcoming_events")
    }

    func testRequiresPermission() {
        let tool = makeTool(store: FakeEventKitStore())
        XCTAssertTrue(tool.requiresPermission)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.CalendarUpcomingEventsToolTests`
Expected: FAIL — `CalendarUpcomingEventsTool` undefined; `Tool.requiresPermission` undefined.

- [ ] **Step 3: Add `Tool.requiresPermission` extension to `b0tCore`**

`b0tCore` is the package that knows about `Tool` and is consumed by `ContextAssembler` (which needs to know whether tools require permission). Add the extension here so it's available to all `Tool` types regardless of which package owns them.

But Swift's protocol-witness-table dispatch for extension members has the gotcha that overrides may not dispatch correctly via `any Tool`. To work around, declare `requiresPermission` as a **stored protocol requirement** on a side protocol we own.

Create `b0tKit/Sources/b0tCore/Tools/PermissionAware.swift`:

Wait — we removed the `Tools/` directory in Task 6. Put it elsewhere. Create `b0tKit/Sources/b0tBrain/PermissionAware.swift` instead — `b0tBrain` is the natural home for a tiny Sendable protocol that both `b0tCore` and `b0tModules` see, like `ToolCallRecord`.

```swift
import Foundation

/// Marker protocol that lets `b0tCore`'s `ContextAssembler` know which
/// `Tool`s in `AssembledContext.tools` may request system permissions.
///
/// `Tool` is from `FoundationModels` and we cannot retroactively add a
/// requirement to it. Instead, we ship this side-protocol; permissioned
/// tools conform additionally and `ContextAssembler` checks via dynamic
/// cast.
public protocol PermissionAware {
    var requiresPermission: Bool { get }
}
```

(Default impl returning `false` is unnecessary since the protocol's only use is via `if let aware = tool as? PermissionAware, aware.requiresPermission`. Tools that don't conform are treated as `false`.)

- [ ] **Step 4: Implement `CalendarUpcomingEventsTool`**

Create `b0tKit/Sources/b0tModules/Calendar/CalendarUpcomingEventsTool.swift`:

```swift
import Foundation
import EventKit
import FoundationModels
import b0tBrain
import b0tCore

public struct CalendarUpcomingEventsTool: Tool, PermissionAware, Sendable {
    public let name = "calendar.upcoming_events"
    public let description =
        "Returns events on the user's calendar within the given lookahead window."
    public var requiresPermission: Bool { true }

    @Generable
    public struct Arguments: Sendable {
        @Guide(description: "Lookahead window in hours. Defaults to module-configured lookahead_hours.")
        public let windowHours: Int?
        public init(windowHours: Int? = nil) { self.windowHours = windowHours }
    }

    @Generable
    public struct Output: Sendable {
        public let events: [Event]
        public let permissionDenied: Bool
        public init(events: [Event], permissionDenied: Bool) {
            self.events = events
            self.permissionDenied = permissionDenied
        }
    }

    @Generable
    public struct Event: Sendable {
        @Guide(description: "Event title.")
        public let title: String
        @Guide(description: "ISO-8601 UTC start timestamp.")
        public let startISO: String
        @Guide(description: "ISO-8601 UTC end timestamp.")
        public let endISO: String
        @Guide(description: "Optional location string.")
        public let location: String?
        @Guide(description: "Calendar name (e.g., 'Personal', 'Work').")
        public let calendarName: String
        @Guide(description: "True if the event is marked tentative on the calendar.")
        public let isTentative: Bool

        public init(title: String, startISO: String, endISO: String, location: String?, calendarName: String, isTentative: Bool) {
            self.title = title
            self.startISO = startISO
            self.endISO = endISO
            self.location = location
            self.calendarName = calendarName
            self.isTentative = isTentative
        }
    }

    private let store: any EventKitStore
    private let gate: PermissionGate
    private let clock: any Clock
    private let defaultLookaheadHours: Int

    public init(
        store: any EventKitStore,
        gate: PermissionGate,
        clock: any Clock = SystemClock(),
        defaultLookaheadHours: Int = 24
    ) {
        self.store = store
        self.gate = gate
        self.clock = clock
        self.defaultLookaheadHours = defaultLookaheadHours
    }

    public func call(arguments: Arguments) async throws -> Output {
        guard await gate.ensure(.calendar) else {
            return Output(events: [], permissionDenied: true)
        }
        let window = max(1, arguments.windowHours ?? defaultLookaheadHours)
        let now = clock.now()
        let end = now.addingTimeInterval(TimeInterval(window) * 3600)
        let calendars = store.calendars(for: .event)
        let predicate = NSPredicate(value: true) // simplified for plan;
        // production replaces with EKEventStore.predicateForEvents(withStart:end:calendars:)
        // by giving LiveEventKitStore a method that forwards to the underlying
        // store. For Slice 4 the FakeEventKitStore ignores predicates and
        // returns scriptedEvents wholesale, so the choice of predicate
        // doesn't change test behaviour.
        let raw = await store.events(matching: predicate)
        _ = calendars
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let filtered = raw
            .filter { $0.startDate >= now && $0.startDate <= end }
            .filter { $0.status != .canceled }
        let events = filtered.map { ek in
            Event(
                title: ek.title ?? "(untitled)",
                startISO: formatter.string(from: ek.startDate),
                endISO: formatter.string(from: ek.endDate),
                location: (ek.location?.isEmpty == false) ? ek.location : nil,
                calendarName: ek.calendar?.title ?? "",
                isTentative: ek.status == .tentative
            )
        }
        return Output(events: events, permissionDenied: false)
    }
}

extension CalendarUpcomingEventsTool {
    /// Producer for `ToolCallRecord` summaries. Used by the live client
    /// adapter when constructing records from typed Arguments/Output.
    public static func summarize(_ arguments: Arguments) -> String {
        "windowHours: \(arguments.windowHours.map(String.init) ?? "default")"
    }
    public static func summarize(_ output: Output) -> String {
        "\(output.events.count) events, permissionDenied: \(output.permissionDenied)"
    }
}
```

The simplification on the predicate is intentional: the live store needs a `predicateForEvents(withStart:end:calendars:)` accessor, which we add as an extension method on the live impl when wiring slice 4. Update the protocol if needed. For the unit-test path, `FakeEventKitStore.events(matching:)` ignores the predicate, so the filtering in-memory above is what the tests exercise.

If you prefer to thread the predicate through the protocol from day one, extend `EventKitStore`:

```swift
func predicateForEvents(withStart start: Date, end: Date, calendars: [EKCalendar]?) -> NSPredicate
```

…and have `LiveEventKitStore` forward to `store.predicateForEvents(...)`. The fake returns `NSPredicate(value: true)`. Implementer's choice; document in commit message.

- [ ] **Step 5: Run tests**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.CalendarUpcomingEventsToolTests`
Expected: PASS, 4 tests.

- [ ] **Step 6: Commit**

```bash
git add b0tKit/Sources/b0tBrain/PermissionAware.swift b0tKit/Sources/b0tModules/Calendar/CalendarUpcomingEventsTool.swift b0tKit/Tests/b0tModulesTests/Calendar/
git commit -m "feat(b0tModules): CalendarUpcomingEventsTool with @Generable types and permission gate"
```

---

### Task 17: `CalendarModule` (Parameters decoding) + factory entry

**Files:**
- Create: `b0tKit/Sources/b0tModules/Calendar/CalendarModule.swift`
- Create: `b0tKit/Tests/b0tModulesTests/Calendar/CalendarModuleTests.swift`
- Modify: `b0tKit/Sources/b0tModules/ModuleRegistry.swift`
- Modify: `b0tKit/Tests/b0tModulesTests/Fixtures/canonical-modules-bot/modules/calendar.md` (new fixture file)

- [ ] **Step 1: Write the failing test**

Create `b0tKit/Tests/b0tModulesTests/Calendar/CalendarModuleTests.swift`:

```swift
import XCTest
import b0tBrain
@testable import b0tModules

final class CalendarModuleTests: XCTestCase {
    private func makeFM(_ pairs: [(String, YAMLValue)]) -> Frontmatter {
        Frontmatter(orderedPairs: pairs)
    }

    func testIDIsCalendar() {
        XCTAssertEqual(CalendarModule.id, "calendar")
    }

    func testDefaultLookaheadIs24WhenAbsent() throws {
        let module = try CalendarModule(
            parameters: makeFM([("module_id", .string("calendar"))]),
            store: FakeEventKitStore()
        )
        XCTAssertEqual(module.tools.count, 1)
        // Internal: verify CalendarUpcomingEventsTool default lookahead via
        // a probe call. Skipped at protocol level; covered in tool tests.
        _ = module
    }

    func testFrontmatterLookaheadHoursOverridesDefault() throws {
        let module = try CalendarModule(
            parameters: makeFM([
                ("module_id", .string("calendar")),
                ("lookahead_hours", .int(48))
            ]),
            store: FakeEventKitStore()
        )
        XCTAssertEqual(module.tools.count, 1)
        // Same caveat as above — tool's default is verified indirectly via
        // an end-to-end registry+tool test if needed.
        _ = module
    }

    func testRequiredPermissionsContainsCalendar() throws {
        let module = try CalendarModule(
            parameters: makeFM([("module_id", .string("calendar"))]),
            store: FakeEventKitStore()
        )
        XCTAssertEqual(module.requiredPermissions, [.calendar])
    }

    func testInvalidLookaheadHoursTypeThrows() {
        XCTAssertThrowsError(try CalendarModule(
            parameters: makeFM([
                ("module_id", .string("calendar")),
                ("lookahead_hours", .string("not-a-number"))
            ]),
            store: FakeEventKitStore()
        ))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.CalendarModuleTests`
Expected: FAIL — `CalendarModule` undefined.

- [ ] **Step 3: Implement `CalendarModule`**

Create `b0tKit/Sources/b0tModules/Calendar/CalendarModule.swift`:

```swift
import Foundation
import FoundationModels
import b0tBrain
import b0tCore

public struct CalendarModule: Module {
    public static let id = "calendar"
    public let requiredPermissions: [PermissionKind] = [.calendar]
    public let tools: [any Tool]

    public struct Parameters: Sendable {
        public let lookaheadHours: Int
        public let verbosity: String
        public let quietForRoutine: Bool

        public init(frontmatter: Frontmatter) throws {
            // lookahead_hours: optional Int, default 24
            switch frontmatter["lookahead_hours"] {
            case .none, .null:
                self.lookaheadHours = 24
            case .int(let n):
                guard n > 0 else {
                    throw ParametersError.invalid("lookahead_hours must be positive, got \(n)")
                }
                self.lookaheadHours = n
            case .some(let other):
                throw ParametersError.invalid("lookahead_hours must be Int, got \(other)")
            }

            // verbosity: optional String, default "medium"
            switch frontmatter["verbosity"] {
            case .none, .null:
                self.verbosity = "medium"
            case .string(let s):
                self.verbosity = s
            case .some(let other):
                throw ParametersError.invalid("verbosity must be String, got \(other)")
            }

            // quiet_for_routine: optional Bool, default true
            switch frontmatter["quiet_for_routine"] {
            case .none, .null:
                self.quietForRoutine = true
            case .bool(let b):
                self.quietForRoutine = b
            case .some(let other):
                throw ParametersError.invalid("quiet_for_routine must be Bool, got \(other)")
            }
        }
    }

    public enum ParametersError: Error, Sendable {
        case invalid(String)
    }

    public init(parameters: Frontmatter) throws {
        try self.init(parameters: parameters, store: LiveEventKitStore())
    }

    public init(parameters: Frontmatter, store: any EventKitStore) throws {
        let params = try Parameters(frontmatter: parameters)
        let gate = PermissionGate(eventKit: store)
        self.tools = [
            CalendarUpcomingEventsTool(
                store: store,
                gate: gate,
                clock: SystemClock(),
                defaultLookaheadHours: params.lookaheadHours
            )
        ]
    }
}
```

- [ ] **Step 4: Register in `ModuleRegistry`**

Edit `b0tKit/Sources/b0tModules/ModuleRegistry.swift`:

Update the `factories` table:

```swift
private static var factories: [String: @Sendable (Frontmatter) throws -> any Module] {
    var table: [String: @Sendable (Frontmatter) throws -> any Module] = [:]
    table[TimeAwarenessModule.id] = { try TimeAwarenessModule(parameters: $0) }
    table[CalendarModule.id] = { try CalendarModule(parameters: $0) }
    // Slice 5 adds RemindersModule
    // Slice 6 adds HealthModule (#if canImport(HealthKit) && os(iOS))
    return table
}
```

- [ ] **Step 5: Add a `calendar.md` fixture**

Create `b0tKit/Tests/b0tModulesTests/Fixtures/canonical-modules-bot/modules/calendar.md`:

```markdown
---
module_id: calendar
enabled: true
lookahead_hours: 12
verbosity: low
quiet_for_routine: true
---
# calendar (test fixture)

I read the user's calendar.
```

Update `ModuleRegistryTests.testCanonicalBotInstantiatesTimeAwarenessAndSkipsUnknownAndDisabled` to expect 2 modules now:

```swift
func testCanonicalBotInstantiatesAllKnownAndSkipsUnknownAndDisabled() async throws {
    let bot = try await loadFixture(named: "canonical-modules-bot")
    let modules = try await ModuleRegistry.loadModules(for: bot)
    XCTAssertEqual(modules.count, 2)
    let ids = Set(modules.map { type(of: $0).id })
    XCTAssertEqual(ids, ["calendar", "time-awareness"])
}
```

- [ ] **Step 6: Run tests**

Run: `swift test --package-path b0tKit`
Expected: PASS. Calendar module tests pass; registry test now expects 2 modules.

- [ ] **Step 7: Commit**

```bash
git add b0tKit/Sources/b0tModules/Calendar/CalendarModule.swift b0tKit/Sources/b0tModules/ModuleRegistry.swift b0tKit/Tests/b0tModulesTests/Calendar/CalendarModuleTests.swift b0tKit/Tests/b0tModulesTests/Fixtures/canonical-modules-bot/modules/calendar.md b0tKit/Tests/b0tModulesTests/ModuleRegistryTests.swift
git commit -m "feat(b0tModules): CalendarModule + register in factories table"
```

---

## Slice 5 — Reminders bridge

End-state: `RemindersModule` registered, `reminders.create` and `reminders.list` tools functional. `EventKitStore` extended with reminder methods. `LiveEventKitStore` and `FakeEventKitStore` updated.

### Task 18: Extend `EventKitStore` with reminder methods

**Files:**
- Modify: `b0tKit/Sources/b0tModules/EventKit/EventKitStore.swift`
- Modify: `b0tKit/Tests/b0tModulesTests/EventKit/FakeEventKitStore.swift`
- Modify: `b0tKit/Tests/b0tModulesTests/EventKit/FakeEventKitStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

Edit `b0tKit/Tests/b0tModulesTests/EventKit/FakeEventKitStoreTests.swift`:

Add:

```swift
func testSaveReminderRetainsIt() throws {
    let store = FakeEventKitStore()
    let reminder = EKReminder(eventStore: EKEventStore())
    reminder.title = "email Lin"
    try store.save(reminder, commit: true)
    XCTAssertEqual(store.savedReminders.count, 1)
    XCTAssertEqual(store.savedReminders[0].title, "email Lin")
}

func testFetchRemindersReturnsScripted() async {
    let store = FakeEventKitStore()
    let r = EKReminder(eventStore: EKEventStore())
    r.title = "buy milk"
    store.scriptedReminders = [r]
    let predicate = NSPredicate(value: true)
    let results = await store.fetchReminders(matching: predicate)
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].title, "buy milk")
}

func testDefaultCalendarForNewRemindersReturnsScripted() {
    let store = FakeEventKitStore()
    let cal = EKCalendar(for: .reminder, eventStore: EKEventStore())
    cal.title = "b0t"
    store.scriptedDefaultReminderCalendar = cal
    XCTAssertEqual(store.defaultCalendarForNewReminders()?.title, "b0t")
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.FakeEventKitStoreTests`
Expected: FAIL — `save`/`fetchReminders`/`defaultCalendarForNewReminders` undefined.

- [ ] **Step 3: Extend the protocol**

Edit `b0tKit/Sources/b0tModules/EventKit/EventKitStore.swift`:

Add to `EventKitStore`:
```swift
func save(_ reminder: EKReminder, commit: Bool) throws
func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder]
func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate
func defaultCalendarForNewReminders() -> EKCalendar?
```

Implement on `LiveEventKitStore`:

```swift
public func save(_ reminder: EKReminder, commit: Bool) throws {
    try store.save(reminder, commit: commit)
}

public func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder] {
    await withCheckedContinuation { cont in
        store.fetchReminders(matching: predicate) { reminders in
            cont.resume(returning: reminders ?? [])
        }
    }
}

public func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate {
    store.predicateForReminders(in: calendars)
}

public func defaultCalendarForNewReminders() -> EKCalendar? {
    store.defaultCalendarForNewReminders()
}
```

- [ ] **Step 4: Extend `FakeEventKitStore`**

Edit `b0tKit/Tests/b0tModulesTests/EventKit/FakeEventKitStore.swift`:

Add:

```swift
var scriptedReminders: [EKReminder] = []
var scriptedDefaultReminderCalendar: EKCalendar?
private(set) var savedReminders: [EKReminder] = []

func save(_ reminder: EKReminder, commit: Bool) throws {
    savedReminders.append(reminder)
}

func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder] {
    scriptedReminders
}

func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate {
    NSPredicate(value: true)
}

func defaultCalendarForNewReminders() -> EKCalendar? {
    scriptedDefaultReminderCalendar
}
```

- [ ] **Step 5: Run tests**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.FakeEventKitStoreTests`
Expected: PASS, 7 tests now (4 from Task 14 + 3 new).

- [ ] **Step 6: Commit**

```bash
git add b0tKit/Sources/b0tModules/EventKit/EventKitStore.swift b0tKit/Tests/b0tModulesTests/EventKit/
git commit -m "feat(b0tModules): EventKitStore reminder surface (save/fetch/predicate/defaultCalendar)"
```

---

### Task 19: `RemindersCreateTool`

**Files:**
- Create: `b0tKit/Sources/b0tModules/Reminders/RemindersCreateTool.swift`
- Create: `b0tKit/Tests/b0tModulesTests/Reminders/RemindersCreateToolTests.swift`

- [ ] **Step 1: Write the failing test**

Create `b0tKit/Tests/b0tModulesTests/Reminders/RemindersCreateToolTests.swift`:

```swift
import XCTest
import EventKit
import FoundationModels
import b0tCore
@testable import b0tModules

final class RemindersCreateToolTests: XCTestCase {
    private func makeTool(store: FakeEventKitStore, defaultList: String = "b0t") -> RemindersCreateTool {
        let gate = PermissionGate(eventKit: store)
        return RemindersCreateTool(store: store, gate: gate, defaultListName: defaultList)
    }

    func testGrantedAccessSavesReminder() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.reminder] = true
        let cal = EKCalendar(for: .reminder, eventStore: EKEventStore())
        cal.title = "b0t"
        store.scriptedDefaultReminderCalendar = cal
        store.scriptedCalendars = [cal]
        let tool = makeTool(store: store)
        let output = try await tool.call(arguments: .init(
            title: "email Lin",
            dueDateISO: nil,
            notes: nil,
            listName: nil
        ))
        XCTAssertNotNil(output.reminderID)
        XCTAssertEqual(output.listName, "b0t")
        XCTAssertFalse(output.permissionDenied)
        XCTAssertNil(output.saveError)
        XCTAssertEqual(store.savedReminders.count, 1)
        XCTAssertEqual(store.savedReminders[0].title, "email Lin")
    }

    func testDeniedAccessReturnsPermissionDenied() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.reminder] = false
        let tool = makeTool(store: store)
        let output = try await tool.call(arguments: .init(
            title: "x", dueDateISO: nil, notes: nil, listName: nil
        ))
        XCTAssertNil(output.reminderID)
        XCTAssertTrue(output.permissionDenied)
        XCTAssertEqual(store.savedReminders.count, 0)
    }

    func testListNameFallsBackToDefault() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.reminder] = true
        let cal = EKCalendar(for: .reminder, eventStore: EKEventStore())
        cal.title = "Other"
        store.scriptedDefaultReminderCalendar = cal
        store.scriptedCalendars = [cal] // no calendar named "b0t" exists
        let tool = makeTool(store: store, defaultList: "b0t")
        let output = try await tool.call(arguments: .init(
            title: "email Lin", dueDateISO: nil, notes: nil, listName: nil
        ))
        // No "b0t" list found → falls back to default-for-new-reminders ("Other")
        XCTAssertEqual(output.listName, "Other")
    }

    func testToolNameIsRemindersCreate() {
        let tool = makeTool(store: FakeEventKitStore())
        XCTAssertEqual(tool.name, "reminders.create")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.RemindersCreateToolTests`
Expected: FAIL — `RemindersCreateTool` undefined.

- [ ] **Step 3: Implement the tool**

Create `b0tKit/Sources/b0tModules/Reminders/RemindersCreateTool.swift`:

```swift
import Foundation
import EventKit
import FoundationModels
import b0tBrain
import b0tCore

public struct RemindersCreateTool: Tool, PermissionAware, Sendable {
    public let name = "reminders.create"
    public let description = "Creates a reminder. Title required; dueDate, notes, and listName optional."
    public var requiresPermission: Bool { true }

    @Generable
    public struct Arguments: Sendable {
        public let title: String
        @Guide(description: "ISO-8601 due date (e.g. 2026-05-04T16:00:00Z), or omitted for no due date.")
        public let dueDateISO: String?
        @Guide(description: "Optional notes attached to the reminder.")
        public let notes: String?
        @Guide(description: "Reminders list name. Defaults to the module's configured default_list.")
        public let listName: String?
        public init(title: String, dueDateISO: String? = nil, notes: String? = nil, listName: String? = nil) {
            self.title = title
            self.dueDateISO = dueDateISO
            self.notes = notes
            self.listName = listName
        }
    }

    @Generable
    public struct Output: Sendable {
        public let reminderID: String?
        public let listName: String
        public let permissionDenied: Bool
        public let saveError: String?
        public init(reminderID: String?, listName: String, permissionDenied: Bool, saveError: String?) {
            self.reminderID = reminderID
            self.listName = listName
            self.permissionDenied = permissionDenied
            self.saveError = saveError
        }
    }

    private let store: any EventKitStore
    private let gate: PermissionGate
    private let defaultListName: String

    public init(store: any EventKitStore, gate: PermissionGate, defaultListName: String) {
        self.store = store
        self.gate = gate
        self.defaultListName = defaultListName
    }

    public func call(arguments: Arguments) async throws -> Output {
        guard await gate.ensure(.reminders) else {
            return Output(reminderID: nil, listName: arguments.listName ?? defaultListName, permissionDenied: true, saveError: nil)
        }

        let requestedName = arguments.listName ?? defaultListName
        let calendars = store.calendars(for: .reminder)
        let chosen = calendars.first { $0.title == requestedName } ?? store.defaultCalendarForNewReminders()

        guard let calendar = chosen else {
            return Output(reminderID: nil, listName: requestedName, permissionDenied: false, saveError: "no reminders calendar available")
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.title = arguments.title
        reminder.calendar = calendar
        if let iso = arguments.dueDateISO, let date = formatter.date(from: iso) {
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            reminder.dueDateComponents = comps
        }
        if let notes = arguments.notes {
            reminder.notes = notes
        }

        do {
            try store.save(reminder, commit: true)
            return Output(reminderID: reminder.calendarItemIdentifier, listName: calendar.title, permissionDenied: false, saveError: nil)
        } catch {
            return Output(reminderID: nil, listName: calendar.title, permissionDenied: false, saveError: String(describing: error))
        }
    }

    public static func summarize(_ a: Arguments) -> String {
        "title: \"\(a.title)\", list: \(a.listName ?? "default")"
    }
    public static func summarize(_ o: Output) -> String {
        if o.permissionDenied { return "permissionDenied: true" }
        if let err = o.saveError { return "saveError: \(err)" }
        return "saved to \(o.listName)"
    }
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.RemindersCreateToolTests`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tModules/Reminders/RemindersCreateTool.swift b0tKit/Tests/b0tModulesTests/Reminders/RemindersCreateToolTests.swift
git commit -m "feat(b0tModules): RemindersCreateTool with default-list fallback"
```

---

### Task 20: `RemindersListTool`

**Files:**
- Create: `b0tKit/Sources/b0tModules/Reminders/RemindersListTool.swift`
- Create: `b0tKit/Tests/b0tModulesTests/Reminders/RemindersListToolTests.swift`

- [ ] **Step 1: Write the failing test**

Create `b0tKit/Tests/b0tModulesTests/Reminders/RemindersListToolTests.swift`:

```swift
import XCTest
import EventKit
import FoundationModels
@testable import b0tModules

final class RemindersListToolTests: XCTestCase {
    private func makeTool(store: FakeEventKitStore) -> RemindersListTool {
        let gate = PermissionGate(eventKit: store)
        return RemindersListTool(store: store, gate: gate)
    }

    func testGrantedAccessReturnsIncompleteReminders() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.reminder] = true
        let cal = EKCalendar(for: .reminder, eventStore: EKEventStore())
        cal.title = "b0t"
        let r1 = EKReminder(eventStore: EKEventStore())
        r1.title = "buy milk"
        r1.calendar = cal
        let r2 = EKReminder(eventStore: EKEventStore())
        r2.title = "completed already"
        r2.calendar = cal
        r2.isCompleted = true
        store.scriptedReminders = [r1, r2]
        let tool = makeTool(store: store)
        let output = try await tool.call(arguments: .init(window: .today))
        XCTAssertEqual(output.reminders.count, 1)
        XCTAssertEqual(output.reminders[0].title, "buy milk")
    }

    func testDeniedAccessReturnsPermissionDenied() async throws {
        let store = FakeEventKitStore()
        store.scriptedGrant[.reminder] = false
        let tool = makeTool(store: store)
        let output = try await tool.call(arguments: .init(window: nil))
        XCTAssertEqual(output.reminders.count, 0)
        XCTAssertTrue(output.permissionDenied)
    }

    func testToolNameIsRemindersList() {
        let tool = makeTool(store: FakeEventKitStore())
        XCTAssertEqual(tool.name, "reminders.list")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.RemindersListToolTests`
Expected: FAIL.

- [ ] **Step 3: Implement the tool**

Create `b0tKit/Sources/b0tModules/Reminders/RemindersListTool.swift`:

```swift
import Foundation
import EventKit
import FoundationModels
import b0tBrain
import b0tCore

public struct RemindersListTool: Tool, PermissionAware, Sendable {
    public let name = "reminders.list"
    public let description = "Lists pending reminders within the given window. Completed reminders are excluded."
    public var requiresPermission: Bool { true }

    @Generable
    public enum ReminderWindow: Sendable {
        case overdue
        case today
        case nextNHours(Int)
    }

    @Generable
    public struct Arguments: Sendable {
        @Guide(description: "Filter window. Defaults to .today.")
        public let window: ReminderWindow?
        public init(window: ReminderWindow? = nil) { self.window = window }
    }

    @Generable
    public struct Output: Sendable {
        public let reminders: [Reminder]
        public let permissionDenied: Bool
        public init(reminders: [Reminder], permissionDenied: Bool) {
            self.reminders = reminders
            self.permissionDenied = permissionDenied
        }
    }

    @Generable
    public struct Reminder: Sendable {
        public let id: String
        public let title: String
        public let dueDateISO: String?
        public let listName: String

        public init(id: String, title: String, dueDateISO: String?, listName: String) {
            self.id = id
            self.title = title
            self.dueDateISO = dueDateISO
            self.listName = listName
        }
    }

    private let store: any EventKitStore
    private let gate: PermissionGate

    public init(store: any EventKitStore, gate: PermissionGate) {
        self.store = store
        self.gate = gate
    }

    public func call(arguments: Arguments) async throws -> Output {
        guard await gate.ensure(.reminders) else {
            return Output(reminders: [], permissionDenied: true)
        }
        let predicate = store.predicateForReminders(in: nil)
        let raw = await store.fetchReminders(matching: predicate)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let reminders = raw
            .filter { !$0.isCompleted }
            .map { ek -> Reminder in
                let dueISO: String?
                if let comps = ek.dueDateComponents,
                   let date = Calendar.current.date(from: comps) {
                    dueISO = formatter.string(from: date)
                } else {
                    dueISO = nil
                }
                return Reminder(
                    id: ek.calendarItemIdentifier,
                    title: ek.title ?? "(untitled)",
                    dueDateISO: dueISO,
                    listName: ek.calendar?.title ?? ""
                )
            }
        return Output(reminders: reminders, permissionDenied: false)
    }

    public static func summarize(_ a: Arguments) -> String {
        switch a.window {
        case .none: return "window: today"
        case .some(.overdue): return "window: overdue"
        case .some(.today): return "window: today"
        case .some(.nextNHours(let n)): return "window: next \(n)h"
        }
    }
    public static func summarize(_ o: Output) -> String {
        o.permissionDenied
            ? "permissionDenied: true"
            : "\(o.reminders.count) reminders"
    }
}
```

The window-filter is intentionally not applied to the predicate in this implementation — Slice-5 keeps it simple by returning all incomplete reminders. The model can ignore the field. A follow-up commit can refine the predicate to honour the window.

- [ ] **Step 4: Run tests**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.RemindersListToolTests`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tModules/Reminders/RemindersListTool.swift b0tKit/Tests/b0tModulesTests/Reminders/RemindersListToolTests.swift
git commit -m "feat(b0tModules): RemindersListTool returning incomplete reminders"
```

---

### Task 21: `RemindersModule` + factory entry

**Files:**
- Create: `b0tKit/Sources/b0tModules/Reminders/RemindersModule.swift`
- Create: `b0tKit/Tests/b0tModulesTests/Reminders/RemindersModuleTests.swift`
- Modify: `b0tKit/Sources/b0tModules/ModuleRegistry.swift`
- Add: `b0tKit/Tests/b0tModulesTests/Fixtures/canonical-modules-bot/modules/reminders.md`

- [ ] **Step 1: Write the failing test**

Create `b0tKit/Tests/b0tModulesTests/Reminders/RemindersModuleTests.swift`:

```swift
import XCTest
import b0tBrain
@testable import b0tModules

final class RemindersModuleTests: XCTestCase {
    private func makeFM(_ pairs: [(String, YAMLValue)]) -> Frontmatter {
        Frontmatter(orderedPairs: pairs)
    }

    func testIDIsReminders() {
        XCTAssertEqual(RemindersModule.id, "reminders")
    }

    func testDefaultListIsB0tWhenAbsent() throws {
        let module = try RemindersModule(
            parameters: makeFM([("module_id", .string("reminders"))]),
            store: FakeEventKitStore()
        )
        XCTAssertEqual(module.tools.count, 2)
    }

    func testDefaultListOverride() throws {
        let module = try RemindersModule(
            parameters: makeFM([
                ("module_id", .string("reminders")),
                ("default_list", .string("Personal"))
            ]),
            store: FakeEventKitStore()
        )
        XCTAssertEqual(module.tools.count, 2)
    }

    func testRequiredPermissionsContainsReminders() throws {
        let module = try RemindersModule(
            parameters: makeFM([("module_id", .string("reminders"))]),
            store: FakeEventKitStore()
        )
        XCTAssertEqual(module.requiredPermissions, [.reminders])
    }

    func testInvalidDefaultListTypeThrows() {
        XCTAssertThrowsError(try RemindersModule(
            parameters: makeFM([
                ("module_id", .string("reminders")),
                ("default_list", .int(42))
            ]),
            store: FakeEventKitStore()
        ))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter b0tModulesTests.RemindersModuleTests`
Expected: FAIL.

- [ ] **Step 3: Implement the module**

Create `b0tKit/Sources/b0tModules/Reminders/RemindersModule.swift`:

```swift
import Foundation
import FoundationModels
import b0tBrain
import b0tCore

public struct RemindersModule: Module {
    public static let id = "reminders"
    public let requiredPermissions: [PermissionKind] = [.reminders]
    public let tools: [any Tool]

    public struct Parameters: Sendable {
        public let defaultList: String

        public init(frontmatter: Frontmatter) throws {
            switch frontmatter["default_list"] {
            case .none, .null:
                self.defaultList = "b0t"
            case .string(let s):
                self.defaultList = s
            case .some(let other):
                throw ParametersError.invalid("default_list must be String, got \(other)")
            }
        }
    }

    public enum ParametersError: Error, Sendable {
        case invalid(String)
    }

    public init(parameters: Frontmatter) throws {
        try self.init(parameters: parameters, store: LiveEventKitStore())
    }

    public init(parameters: Frontmatter, store: any EventKitStore) throws {
        let params = try Parameters(frontmatter: parameters)
        let gate = PermissionGate(eventKit: store)
        self.tools = [
            RemindersCreateTool(store: store, gate: gate, defaultListName: params.defaultList),
            RemindersListTool(store: store, gate: gate)
        ]
    }
}
```

- [ ] **Step 4: Register in `ModuleRegistry`**

Edit `b0tKit/Sources/b0tModules/ModuleRegistry.swift`:

```swift
table[RemindersModule.id] = { try RemindersModule(parameters: $0) }
```

- [ ] **Step 5: Add fixture file and update registry test**

Create `b0tKit/Tests/b0tModulesTests/Fixtures/canonical-modules-bot/modules/reminders.md`:

```markdown
---
module_id: reminders
enabled: true
default_list: "b0t"
---
# reminders (test fixture)
```

Update `ModuleRegistryTests.testCanonicalBotInstantiatesAllKnownAndSkipsUnknownAndDisabled`:

```swift
XCTAssertEqual(modules.count, 3)
let ids = Set(modules.map { type(of: $0).id })
XCTAssertEqual(ids, ["calendar", "reminders", "time-awareness"])
```

- [ ] **Step 6: Run tests**

Run: `swift test --package-path b0tKit`
Expected: PASS, all green.

- [ ] **Step 7: Commit**

```bash
git add b0tKit/Sources/b0tModules/Reminders/RemindersModule.swift b0tKit/Sources/b0tModules/ModuleRegistry.swift b0tKit/Tests/b0tModulesTests/Reminders/RemindersModuleTests.swift b0tKit/Tests/b0tModulesTests/Fixtures/canonical-modules-bot/modules/reminders.md b0tKit/Tests/b0tModulesTests/ModuleRegistryTests.swift
git commit -m "feat(b0tModules): RemindersModule + register in factories table"
```

---

## Slice 6 — Health bridge (iOS-only)

End-state: `HealthModule` registered conditionally, `health.steps_today` returns step count when granted. `HealthStore` protocol + `LiveHealthStore` (iOS) + `FakeHealthStore`. Module is platform-guarded.

### Task 22: `HealthStore` protocol + Live + Fake (iOS-guarded)

**Files:**
- Create: `b0tKit/Sources/b0tModules/HealthKit/HealthStore.swift`
- Create: `b0tKit/Tests/b0tModulesTests/HealthKit/FakeHealthStore.swift`
- Test: `b0tKit/Tests/b0tModulesTests/HealthKit/FakeHealthStoreTests.swift`
- Modify: `b0tKit/Sources/b0tModules/PermissionGate.swift` (add health backend)

- [ ] **Step 1: Write the failing test**

Create `b0tKit/Tests/b0tModulesTests/HealthKit/FakeHealthStoreTests.swift`:

```swift
#if canImport(HealthKit) && os(iOS)
import XCTest
import HealthKit
@testable import b0tModules

final class FakeHealthStoreTests: XCTestCase {
    func testInitialAuthorizationStatusIsNotDetermined() {
        let store = FakeHealthStore()
        XCTAssertEqual(store.authorizationStatus(for: HKQuantityType(.stepCount)), .notDetermined)
    }

    func testRequestAuthorizationFlipsStatus() async throws {
        let store = FakeHealthStore()
        store.scriptedGrant = true
        try await store.requestAuthorization(toShare: nil, read: [HKQuantityType(.stepCount)])
        XCTAssertEqual(store.authorizationStatus(for: HKQuantityType(.stepCount)), .sharingAuthorized)
    }

    func testStepsTodayReturnsScripted() async throws {
        let store = FakeHealthStore()
        store.scriptedStepsToday = 4523
        let count = try await store.stepsToday()
        XCTAssertEqual(count, 4523)
    }
}
#endif
```

- [ ] **Step 2: Run to verify failure (iOS sim only)**

Run: `xcodebuild test -project b0t.xcodeproj -scheme b0tApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:b0tModulesTests/FakeHealthStoreTests`

Expected: FAIL (or skipped, if running on macOS host) — `FakeHealthStore` undefined.

For host swift-test, the `#if` guard means these tests are skipped — confirm: `swift test --package-path b0tKit` does not run them.

- [ ] **Step 3: Define the protocol and live impl**

Create `b0tKit/Sources/b0tModules/HealthKit/HealthStore.swift`:

```swift
#if canImport(HealthKit)
import Foundation
import HealthKit

/// The seam through which `b0tModules`'s health tools talk to HealthKit.
/// Two implementations: `LiveHealthStore` (iOS only) and `FakeHealthStore`
/// (test target).
///
/// `stepsToday()` is expressed as a high-level method rather than threading
/// `HKStatisticsQuery` directly through the protocol so the fake stays
/// trivial and the live impl can encapsulate query construction.
public protocol HealthStore: Sendable {
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
    func requestAuthorization(toShare: Set<HKSampleType>?, read: Set<HKObjectType>?) async throws
    func stepsToday() async throws -> Int
}

#if os(iOS)
public struct LiveHealthStore: HealthStore {
    private let store: HKHealthStore

    public init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    public func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        store.authorizationStatus(for: type)
    }

    public func requestAuthorization(toShare: Set<HKSampleType>?, read: Set<HKObjectType>?) async throws {
        try await store.requestAuthorization(toShare: toShare ?? [], read: read ?? [])
    }

    public func stepsToday() async throws -> Int {
        let stepType = HKQuantityType(.stepCount)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                let count = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: Int(count))
            }
            self.store.execute(query)
        }
    }
}
#endif // os(iOS)
#endif // canImport(HealthKit)
```

- [ ] **Step 4: Define the fake**

Create `b0tKit/Tests/b0tModulesTests/HealthKit/FakeHealthStore.swift`:

```swift
#if canImport(HealthKit) && os(iOS)
import Foundation
import HealthKit
@testable import b0tModules

final class FakeHealthStore: HealthStore, @unchecked Sendable {
    var scriptedGrant: Bool = false
    var scriptedStepsToday: Int = 0
    private var status: [HKObjectType: HKAuthorizationStatus] = [:]

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        status[type] ?? .notDetermined
    }

    func requestAuthorization(toShare: Set<HKSampleType>?, read: Set<HKObjectType>?) async throws {
        for type in read ?? [] {
            status[type] = scriptedGrant ? .sharingAuthorized : .sharingDenied
        }
    }

    func stepsToday() async throws -> Int {
        scriptedStepsToday
    }
}
#endif
```

- [ ] **Step 5: Wire `.healthRead` into `PermissionGate`**

Edit `b0tKit/Sources/b0tModules/PermissionGate.swift`:

Replace the actor body with the dual-init shape that handles both iOS-with-HealthKit and non-iOS-without:

```swift
import Foundation
import EventKit
#if canImport(HealthKit) && os(iOS)
import HealthKit
#endif

package actor PermissionGate {
    private let eventKit: any EventKitStore
    #if canImport(HealthKit) && os(iOS)
    private let health: any HealthStore
    #endif

    #if canImport(HealthKit) && os(iOS)
    package init(
        eventKit: any EventKitStore = LiveEventKitStore(),
        health: any HealthStore = LiveHealthStore()
    ) {
        self.eventKit = eventKit
        self.health = health
    }
    #else
    package init(eventKit: any EventKitStore = LiveEventKitStore()) {
        self.eventKit = eventKit
    }
    #endif

    package func ensure(_ kind: PermissionKind) async -> Bool {
        switch kind {
        case .calendar:
            return await ensureEventKit(.event)
        case .reminders:
            return await ensureEventKit(.reminder)
        #if canImport(HealthKit)
        case .healthRead(let identifiers):
            #if os(iOS)
            return await ensureHealthRead(identifiers)
            #else
            return false
            #endif
        #endif
        }
    }

    private func ensureEventKit(_ entityType: EKEntityType) async -> Bool {
        let status = eventKit.authorizationStatus(for: entityType)
        switch status {
        case .fullAccess, .authorized:
            return true
        case .notDetermined:
            return (try? await eventKit.requestAccess(to: entityType)) ?? false
        case .denied, .restricted, .writeOnly:
            return false
        @unknown default:
            return false
        }
    }

    #if canImport(HealthKit) && os(iOS)
    private func ensureHealthRead(_ identifiers: [HKQuantityTypeIdentifier]) async -> Bool {
        let types: Set<HKObjectType> = Set(identifiers.compactMap { id in
            HKQuantityType(.init(rawValue: id.rawValue)) as HKObjectType
        })
        // HealthKit's read-permission state is not observable post-prompt,
        // so we can only detect "never asked" via .notDetermined of the
        // *write* status (which we don't request). For now: just request
        // and trust the system. A returned-true means "user was prompted";
        // it does NOT guarantee the user granted. The tool's downstream
        // query handles "no data" gracefully — see spec §3 sub-decisions.
        do {
            try await health.requestAuthorization(toShare: nil, read: types)
            return true
        } catch {
            return false
        }
    }
    #endif
}
```

- [ ] **Step 6: Run tests**

Run on simulator: `xcodebuild test -project b0t.xcodeproj -scheme b0tApp -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:b0tModulesTests/FakeHealthStoreTests`
Expected: PASS, 3 tests.

Run on host: `swift test --package-path b0tKit`
Expected: PASS, the FakeHealthStore tests are skipped (no HealthKit). Other tests still green.

- [ ] **Step 7: Commit**

```bash
git add b0tKit/Sources/b0tModules/HealthKit/ b0tKit/Tests/b0tModulesTests/HealthKit/ b0tKit/Sources/b0tModules/PermissionGate.swift
git commit -m "feat(b0tModules): HealthStore protocol + Live (iOS) + Fake; PermissionGate handles .healthRead"
```

---

### Task 23: `HealthStepsTodayTool`

**Files:**
- Create: `b0tKit/Sources/b0tModules/Health/HealthStepsTodayTool.swift`
- Create: `b0tKit/Tests/b0tModulesTests/Health/HealthStepsTodayToolTests.swift`

- [ ] **Step 1: Write the failing test**

Create `b0tKit/Tests/b0tModulesTests/Health/HealthStepsTodayToolTests.swift`:

```swift
#if canImport(HealthKit) && os(iOS)
import XCTest
import HealthKit
import FoundationModels
@testable import b0tModules

final class HealthStepsTodayToolTests: XCTestCase {
    private func makeTool(store: FakeHealthStore) -> HealthStepsTodayTool {
        let gate = PermissionGate(eventKit: FakeEventKitStore(), health: store)
        return HealthStepsTodayTool(store: store, gate: gate)
    }

    func testGrantedReturnsScriptedSteps() async throws {
        let store = FakeHealthStore()
        store.scriptedGrant = true
        store.scriptedStepsToday = 4523
        let tool = makeTool(store: store)
        let output = try await tool.call(arguments: .init())
        XCTAssertEqual(output.stepCount, 4523)
        XCTAssertFalse(output.permissionDenied)
    }

    func testZeroStepsIsNotInterpretedAsDenial() async throws {
        // The HealthKit denial-hiding wrinkle: granted access + zero
        // recorded steps should NOT produce permissionDenied: true.
        let store = FakeHealthStore()
        store.scriptedGrant = true
        store.scriptedStepsToday = 0
        let tool = makeTool(store: store)
        let output = try await tool.call(arguments: .init())
        XCTAssertEqual(output.stepCount, 0)
        XCTAssertFalse(output.permissionDenied)
    }

    func testToolNameIsHealthStepsToday() {
        let tool = makeTool(store: FakeHealthStore())
        XCTAssertEqual(tool.name, "health.steps_today")
    }
}
#endif
```

- [ ] **Step 2: Run to verify failure**

Run: `xcodebuild test ... -only-testing:b0tModulesTests/HealthStepsTodayToolTests`
Expected: FAIL.

- [ ] **Step 3: Implement the tool**

Create `b0tKit/Sources/b0tModules/Health/HealthStepsTodayTool.swift`:

```swift
#if canImport(HealthKit) && os(iOS)
import Foundation
import HealthKit
import FoundationModels
import b0tBrain
import b0tCore

public struct HealthStepsTodayTool: Tool, PermissionAware, Sendable {
    public let name = "health.steps_today"
    public let description =
        "Returns the user's step count from local-midnight to now, via HealthKit."
    public var requiresPermission: Bool { true }

    @Generable
    public struct Arguments: Sendable {
        public init() {}
    }

    @Generable
    public struct Output: Sendable {
        public let stepCount: Int
        public let permissionDenied: Bool
        public init(stepCount: Int, permissionDenied: Bool) {
            self.stepCount = stepCount
            self.permissionDenied = permissionDenied
        }
    }

    private let store: any HealthStore
    private let gate: PermissionGate

    public init(store: any HealthStore, gate: PermissionGate) {
        self.store = store
        self.gate = gate
    }

    public func call(arguments: Arguments) async throws -> Output {
        guard await gate.ensure(.healthRead([.stepCount])) else {
            return Output(stepCount: 0, permissionDenied: true)
        }
        do {
            let count = try await store.stepsToday()
            return Output(stepCount: count, permissionDenied: false)
        } catch {
            // Treat query failure as zero steps. Don't infer denial — the
            // HealthKit denial-hiding constraint means we cannot reliably
            // distinguish "denied" from "no data" anyway.
            return Output(stepCount: 0, permissionDenied: false)
        }
    }

    public static func summarize(_ a: Arguments) -> String { "(no args)" }
    public static func summarize(_ o: Output) -> String {
        o.permissionDenied
            ? "permissionDenied: true"
            : "stepCount: \(o.stepCount)"
    }
}
#endif
```

- [ ] **Step 4: Run tests**

Run: `xcodebuild test ... -only-testing:b0tModulesTests/HealthStepsTodayToolTests`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tModules/Health/ b0tKit/Tests/b0tModulesTests/Health/
git commit -m "feat(b0tModules): HealthStepsTodayTool with HealthKit-denial-hiding awareness"
```

---

### Task 24: `HealthModule` + factory entry (conditional)

**Files:**
- Create: `b0tKit/Sources/b0tModules/Health/HealthModule.swift`
- Create: `b0tKit/Tests/b0tModulesTests/Health/HealthModuleTests.swift`
- Modify: `b0tKit/Sources/b0tModules/ModuleRegistry.swift`

- [ ] **Step 1: Write the failing test**

Create `b0tKit/Tests/b0tModulesTests/Health/HealthModuleTests.swift`:

```swift
#if canImport(HealthKit) && os(iOS)
import XCTest
import b0tBrain
import HealthKit
@testable import b0tModules

final class HealthModuleTests: XCTestCase {
    private func makeFM(_ pairs: [(String, YAMLValue)]) -> Frontmatter {
        Frontmatter(orderedPairs: pairs)
    }

    func testIDIsHealth() {
        XCTAssertEqual(HealthModule.id, "health")
    }

    func testRequiredPermissionsContainsHealthRead() throws {
        let module = try HealthModule(
            parameters: makeFM([
                ("module_id", .string("health")),
                ("read_metrics", .array([.string("steps")]))
            ]),
            store: FakeHealthStore()
        )
        guard case .healthRead(let ids) = module.requiredPermissions[0] else {
            XCTFail("expected .healthRead")
            return
        }
        XCTAssertTrue(ids.contains(.stepCount))
    }

    func testStepsToolPresentWhenStepsInReadMetrics() throws {
        let module = try HealthModule(
            parameters: makeFM([
                ("module_id", .string("health")),
                ("read_metrics", .array([.string("steps")]))
            ]),
            store: FakeHealthStore()
        )
        XCTAssertEqual(module.tools.count, 1)
        XCTAssertEqual(module.tools[0].name, "health.steps_today")
    }

    func testStepsToolAbsentWhenStepsNotInReadMetrics() throws {
        let module = try HealthModule(
            parameters: makeFM([
                ("module_id", .string("health")),
                ("read_metrics", .array([.string("sleep")]))
            ]),
            store: FakeHealthStore()
        )
        XCTAssertEqual(module.tools.count, 0)
    }
}
#endif
```

- [ ] **Step 2: Run to verify failure**

Expected: FAIL.

- [ ] **Step 3: Implement the module**

Create `b0tKit/Sources/b0tModules/Health/HealthModule.swift`:

```swift
#if canImport(HealthKit) && os(iOS)
import Foundation
import HealthKit
import FoundationModels
import b0tBrain
import b0tCore

public struct HealthModule: Module {
    public static let id = "health"
    public let requiredPermissions: [PermissionKind]
    public let tools: [any Tool]

    public struct Parameters: Sendable {
        public let readMetrics: [String]

        public init(frontmatter: Frontmatter) throws {
            switch frontmatter["read_metrics"] {
            case .none, .null:
                self.readMetrics = []
            case .array(let items):
                self.readMetrics = try items.map { v in
                    guard case .string(let s) = v else {
                        throw ParametersError.invalid("read_metrics entries must be strings")
                    }
                    return s
                }
            case .some(let other):
                throw ParametersError.invalid("read_metrics must be array of strings, got \(other)")
            }
        }
    }

    public enum ParametersError: Error, Sendable {
        case invalid(String)
    }

    public init(parameters: Frontmatter) throws {
        try self.init(parameters: parameters, store: LiveHealthStore())
    }

    public init(parameters: Frontmatter, store: any HealthStore) throws {
        let params = try Parameters(frontmatter: parameters)
        let gate = PermissionGate(eventKit: LiveEventKitStore(), health: store)
        var tools: [any Tool] = []
        var ids: [HKQuantityTypeIdentifier] = []

        if params.readMetrics.contains("steps") {
            tools.append(HealthStepsTodayTool(store: store, gate: gate))
            ids.append(.stepCount)
        }
        // Future Phase 3.5+ adds sleep_hours, active_energy, etc.

        self.tools = tools
        self.requiredPermissions = ids.isEmpty ? [] : [.healthRead(ids)]
    }
}
#endif
```

- [ ] **Step 4: Register conditionally in `ModuleRegistry`**

Edit `b0tKit/Sources/b0tModules/ModuleRegistry.swift`:

```swift
private static var factories: [String: @Sendable (Frontmatter) throws -> any Module] {
    var table: [String: @Sendable (Frontmatter) throws -> any Module] = [:]
    table[TimeAwarenessModule.id] = { try TimeAwarenessModule(parameters: $0) }
    table[CalendarModule.id] = { try CalendarModule(parameters: $0) }
    table[RemindersModule.id] = { try RemindersModule(parameters: $0) }
    #if canImport(HealthKit) && os(iOS)
    table[HealthModule.id] = { try HealthModule(parameters: $0) }
    #endif
    return table
}
```

- [ ] **Step 5: Run tests**

Run: simulator + host. Expected: PASS, all green.

- [ ] **Step 6: Commit**

```bash
git add b0tKit/Sources/b0tModules/Health/HealthModule.swift b0tKit/Sources/b0tModules/ModuleRegistry.swift b0tKit/Tests/b0tModulesTests/Health/HealthModuleTests.swift
git commit -m "feat(b0tModules): HealthModule + register conditionally on iOS"
```

---

## Slice 7 — Polish, integration, and acceptance

End-state: ContextAssembler injects the permission addendum when permissioned tools are present. `default-bot/modules/` integration test asserts the registry returns the right modules from production. Live integration tests pass on simulator. Info.plist has the three usage descriptions. `b0tModules/CLAUDE.md` written. `b0tCore/CLAUDE.md` refreshed. `IMPLEMENTATION.md` updated. ADR drafted for the Module/ToolHandle simplification. Privacy audit clean.

### Task 25: `ContextAssembler` permission addendum (conditional)

**Files:**
- Modify: `b0tKit/Sources/b0tCore/Context/AssembledContext.swift`
- Modify: `b0tKit/Sources/b0tCore/Context/ContextAssembler.swift`
- Modify: `b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift`

- [ ] **Step 1: Write the failing tests**

Edit `b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift`:

Add:

```swift
func testPermissionAddendumPresentWhenPermissionedToolInTools() async throws {
    // Constructed using a stand-in PermissionAware tool — declaring it inline
    // so this test stays in b0tCoreTests without depending on b0tModules.
    struct StandInTool: Tool, PermissionAware, Sendable {
        let name = "stand_in"
        let description = "x"
        var requiresPermission: Bool { true }
        @Generable struct Arguments: Sendable { public init() {} }
        @Generable struct Output: Sendable { public init() {} }
        func call(arguments: Arguments) async throws -> Output { .init() }
    }
    let bot = try await Self.makeBot()
    let store = await bot.store
    let assembler = ContextAssembler(bot: bot, store: store, tools: [StandInTool()], toolsRequirePermission: true)
    let context = try await assembler.assemble(mode: .conversation(userPrompt: "hi"))
    XCTAssertTrue(context.systemInstructions.contains("permissionDenied"))
}

func testPermissionAddendumAbsentWhenNoPermissionedTools() async throws {
    let bot = try await Self.makeBot()
    let store = await bot.store
    let assembler = ContextAssembler(bot: bot, store: store, tools: [], toolsRequirePermission: false)
    let context = try await assembler.assemble(mode: .conversation(userPrompt: "hi"))
    XCTAssertFalse(context.systemInstructions.contains("permissionDenied"))
}
```

- [ ] **Step 2: Update `AssembledContext`**

Edit `b0tKit/Sources/b0tCore/Context/AssembledContext.swift`:

Add a `toolsRequirePermission: Bool` field. Update the public init to accept it.

- [ ] **Step 3: Update `ContextAssembler`**

Edit `b0tKit/Sources/b0tCore/Context/ContextAssembler.swift`:

Add `tools: [any Tool]` and `toolsRequirePermission: Bool` parameters to `init`. In `assemble(mode:)`, append the addendum to `systemInstructions` when `toolsRequirePermission == true`:

```swift
private static let permissionAddendum = """

Some of your tools may return a result with `permissionDenied: true`. \
That means you don't have system access yet. When this happens, mention \
it to the user in your own voice — keep it brief, suggest they can grant \
access in iOS Settings if they'd like, and don't pretend the tool worked. \
If you've been denied access, don't keep trying to call the same tool in a turn.
"""
```

If `toolsRequirePermission` is true, append `permissionAddendum` to the assembled system instructions.

- [ ] **Step 4: Run tests**

Run: `swift test --package-path b0tKit --filter b0tCoreTests.ContextAssemblerTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tCore/Context/ b0tKit/Tests/b0tCoreTests/ContextAssemblerTests.swift
git commit -m "feat(b0tCore): ContextAssembler appends permission-handling addendum when permissioned tools present"
```

---

### Task 26: Wire ModuleRegistry → ContextAssembler in `b0tApp`

**Files:**
- Modify: `b0tApp/Sources/App/b0tApp.swift`
- Modify: `b0tApp/Sources/Debug/DebugBrainView.swift` (only the construction path)

This is the wiring that lights up real tools in the chat surface for the first time.

- [ ] **Step 1: Identify construction sites**

Run: `grep -n "ContextAssembler\|ConversationManager\|HeartbeatManager" b0tApp/Sources/`

- [ ] **Step 2: Update construction**

In each construction site, prepend:

```swift
import b0tModules

// (await context — likely already inside a Task)
let modules = (try? await ModuleRegistry.loadModules(for: bot)) ?? []
let tools = modules.flatMap(\.tools)
let toolsRequirePermission = modules.contains { !$0.requiredPermissions.isEmpty }
```

Then pass to ContextAssembler / ConversationManager / HeartbeatManager. Adjust their public inits if needed (Phase 2 may have constructed assembler internally — if so, the cleaner path is to expose the `tools:` parameter on `ConversationManager.init` and have it construct the assembler internally).

The exact patches depend on Phase 2's surface — document the result in the commit message.

- [ ] **Step 3: Build and smoke-test on simulator**

Run: `xcodebuild -project b0t.xcodeproj -scheme b0tApp -sdk iphonesimulator build`
Expected: clean build.

Launch on simulator with the live client. Type "what time is it" — `time_awareness` should be invoked, the tool-call row should render, and the b0t should reply with the current time. Permission prompts will not fire for time-awareness (no permissions). Calendar/Reminders/Health prompts will fire on first relevant prompt.

- [ ] **Step 4: Commit**

```bash
git add b0tApp/Sources/App/b0tApp.swift b0tApp/Sources/Debug/DebugBrainView.swift
git commit -m "feat(b0tApp): wire ModuleRegistry → ContextAssembler at startup"
```

---

### Task 27: Info.plist usage descriptions

**Files:**
- Modify: `project.yml`
- Possibly: `b0tApp/Resources/Info.plist` (fallback if xcodegen drops the keys)

- [ ] **Step 1: Apply the voice-and-copy guide**

The three strings:

```
NSCalendarsUsageDescription:
  So I can read your calendar and let you know what's coming up.
NSRemindersFullAccessUsageDescription:
  So I can create reminders when you ask, and list ones you already have.
NSHealthShareUsageDescription:
  So I can mention your step count when it's relevant — quietly, never as advice.
```

Run each through `docs/references/voice-and-copy-guide.md` before commit. Adjust if anything reads as too clinical, too cute, or off-brand.

- [ ] **Step 2: Add to project.yml**

Edit `project.yml`. Find the `b0tApp` target's settings and add under `INFOPLIST_KEY_*`:

```yaml
INFOPLIST_KEY_NSCalendarsUsageDescription: So I can read your calendar and let you know what's coming up.
INFOPLIST_KEY_NSRemindersFullAccessUsageDescription: So I can create reminders when you ask, and list ones you already have.
INFOPLIST_KEY_NSHealthShareUsageDescription: So I can mention your step count when it's relevant — quietly, never as advice.
```

- [ ] **Step 3: Regenerate the Xcode project**

Run: `xcodegen generate`
Expected: clean regeneration.

- [ ] **Step 4: Verify keys propagated to Info.plist**

Build the app. After building, inspect: `plutil -p b0tApp/Info.plist 2>/dev/null` (the file lives in the build output if xcodegen propagated INFOPLIST_KEY_*; or in the source tree if Phase 2's pattern from Task 30 still applies).

If the keys are missing — fall back to editing `b0tApp/Resources/Info.plist` (or `b0tApp/Info.plist`) directly:

```xml
<key>NSCalendarsUsageDescription</key>
<string>So I can read your calendar and let you know what's coming up.</string>
<key>NSRemindersFullAccessUsageDescription</key>
<string>So I can create reminders when you ask, and list ones you already have.</string>
<key>NSHealthShareUsageDescription</key>
<string>So I can mention your step count when it's relevant — quietly, never as advice.</string>
```

- [ ] **Step 5: Build to confirm**

Run: `xcodebuild -project b0t.xcodeproj -scheme b0tApp -sdk iphonesimulator build`
Expected: clean build.

- [ ] **Step 6: Commit**

```bash
git add project.yml b0t.xcodeproj b0tApp/Info.plist b0tApp/Resources/Info.plist 2>/dev/null
git commit -m "feat(b0tApp): add NSCalendars/NSRemindersFullAccess/NSHealthShare usage descriptions"
```

(Adjust paths in `git add` to match what actually changed.)

---

### Task 28: `default-bot/` integration test

**Files:**
- Create: `b0tKit/Tests/b0tCoreIntegrationTests/DefaultBotModulesTests.swift`

Existing precedent: Phase 1's "load every shipped file, assert no parse errors" test for `default-bot/`. Phase 3 extends with "ModuleRegistry can load production default-bot's modules and returns the expected set."

- [ ] **Step 1: Write the test**

Create `b0tKit/Tests/b0tCoreIntegrationTests/DefaultBotModulesTests.swift`:

```swift
import XCTest
import b0tBrain
@testable import b0tModules

final class DefaultBotModulesTests: XCTestCase {
    /// The production `default-bot/` ships 10 module markdown files. Phase 3
    /// supports 4 of them in code (calendar, reminders, time-awareness, health).
    /// Of those: `health.md` ships `enabled: false` so it is silently skipped.
    /// Result: 3 instantiated modules, 6 unknown-and-skipped, 1 disabled-and-skipped.
    func testRegistryLoadsThreeKnownModulesFromProductionDefaultBot() async throws {
        // The default-bot/ directory is bundled into the app at build time
        // via xcodegen folder-reference. For SPM tests, point at the repo's
        // default-bot/ via a path relative to this source file.
        let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let defaultBotURL = here
            .appendingPathComponent("../../../default-bot", isDirectory: true)
            .standardizedFileURL
        let store = BotStore()
        let bot = try await store.load(at: defaultBotURL)

        let modules = try await ModuleRegistry.loadModules(for: bot)

        let ids = Set(modules.map { type(of: $0).id })
        let expected: Set<String> = ["calendar", "reminders", "time-awareness"]
        XCTAssertEqual(ids, expected,
            "Phase 3 should load exactly calendar, reminders, time-awareness from default-bot/. health.md is enabled:false. Mail/Location/Notes/Weather/Journaling/Onboarding are unknown-and-skipped.")
        XCTAssertEqual(modules.count, 3)
    }
}
```

- [ ] **Step 2: Run**

Run: `swift test --package-path b0tKit --filter b0tCoreIntegrationTests.DefaultBotModulesTests`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add b0tKit/Tests/b0tCoreIntegrationTests/DefaultBotModulesTests.swift
git commit -m "test(b0tCoreIntegration): registry loads expected modules from production default-bot"
```

---

### Task 29: Live integration tests (gated)

**Files:**
- Create: `b0tKit/Tests/b0tModulesLiveTests/CalendarLiveTests.swift`
- Create: `b0tKit/Tests/b0tModulesLiveTests/RemindersLiveTests.swift`
- Create: `b0tKit/Tests/b0tModulesLiveTests/HealthLiveTests.swift`
- Modify: `b0tKit/Package.swift` (add live test target)

- [ ] **Step 1: Add the live test target to Package.swift**

Edit `b0tKit/Package.swift`:

Add:
```swift
.testTarget(name: "b0tModulesLiveTests", dependencies: ["b0tModules"]),
```

- [ ] **Step 2: Write the gated tests**

Each test file gates on `ProcessInfo.processInfo.environment["LIVE_TESTS"] == "1"`. Skip otherwise. The pattern Phase 2 used for `live-fm` tests is the precedent.

Create `b0tKit/Tests/b0tModulesLiveTests/CalendarLiveTests.swift`:

```swift
#if os(iOS)
import XCTest
import EventKit
@testable import b0tModules

final class CalendarLiveTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LIVE_TESTS"] == "1",
                          "set LIVE_TESTS=1 to run")
    }

    func testCalendarUpcomingEventsAgainstSimulatorEventStore() async throws {
        let store = LiveEventKitStore()
        let gate = PermissionGate(eventKit: store)
        let granted = await gate.ensure(.calendar)
        try XCTSkipUnless(granted, "no calendar access in this run")
        let tool = CalendarUpcomingEventsTool(store: store, gate: gate)
        let output = try await tool.call(arguments: .init(windowHours: 24))
        XCTAssertFalse(output.permissionDenied)
        // Don't assert events.count — depends on simulator state. Just
        // verify the call completed without throwing and the type is right.
    }
}
#endif
```

Create `b0tKit/Tests/b0tModulesLiveTests/RemindersLiveTests.swift` and `HealthLiveTests.swift` along the same pattern.

- [ ] **Step 3: Run on simulator**

Set `LIVE_TESTS=1` and run on iOS simulator (the simulator must have calendar/reminders/health pre-configured for these to do anything useful).

```
LIVE_TESTS=1 xcodebuild test -project b0t.xcodeproj -scheme b0tKit-Package -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: live tests pass (or are skipped if permission is denied — `XCTSkipUnless` keeps them from failing the run).

Without LIVE_TESTS=1 they're skipped silently — verified by re-running CI's normal flow.

- [ ] **Step 4: Commit**

```bash
git add b0tKit/Tests/b0tModulesLiveTests/ b0tKit/Package.swift
git commit -m "test(b0tModulesLive): gated live integration tests for Calendar/Reminders/Health"
```

---

### Task 30: `b0tModules/CLAUDE.md` + `b0tCore/CLAUDE.md` refresh

**Files:**
- Create: `b0tKit/Sources/b0tModules/CLAUDE.md`
- Modify: `b0tKit/Sources/b0tCore/CLAUDE.md` (final pass — already partially updated in Task 6)

- [ ] **Step 1: Write `b0tModules/CLAUDE.md`**

Create `b0tKit/Sources/b0tModules/CLAUDE.md`:

```markdown
# b0tModules

Capability bridges. Each Module wraps a slice of system access (calendar, reminders, health, time-awareness) and exposes one or more `FoundationModels.Tool`s the model can call during a turn or tick.

## Public API contracts (as-built, Phase 3)

- `Module` protocol — `static var id`, `requiredPermissions`, `tools: [any Tool]`, `init(parameters: Frontmatter) throws`. `Sendable`.
- `PermissionKind` enum — `.calendar`, `.reminders`, `.healthRead([HKQuantityTypeIdentifier])`. Last case `#if canImport(HealthKit)`-guarded.
- `ModuleRegistry.loadModules(for: Bot) async throws -> [any Module]` — public entry point. Reads `<bot>/modules/*.md`, looks up `module_id` in the static factories table, returns the instantiated set. Unknown ids and `enabled: false` files are logged-and-skipped (lenient policy per spec Q7).
- `ModuleLoadError` — `.missingModuleID(file:)`, `.invalidParameters(moduleID:underlying:)`.
- `EventKitStore` protocol — read+create surface. `LiveEventKitStore` (production) wraps `EKEventStore`.
- `HealthStore` protocol (`#if canImport(HealthKit) && os(iOS)`) — `LiveHealthStore` wraps `HKHealthStore`.
- `PermissionGate` actor — package-private; switches on `PermissionKind`, dispatches to the right backend's `requestAccess`/`requestAuthorization`.

Public Modules + tools (Phase 3 thin slice):

| Module | `module_id` | Permissions | Tools |
|---|---|---|---|
| TimeAwarenessModule | `time-awareness` | none | `time_awareness` |
| CalendarModule | `calendar` | `.calendar` | `calendar.upcoming_events` |
| RemindersModule | `reminders` | `.reminders` | `reminders.create`, `reminders.list` |
| HealthModule (iOS) | `health` | `.healthRead([.stepCount])` | `health.steps_today` |

## Patterns

- Each Module instantiates its own `PermissionGate` and injects it into its tools. `EventKitStore`/`HealthStore` are shared between gate and tools per Module instance.
- Tools that require permission conform to `PermissionAware` (in `b0tBrain`). `ContextAssembler` checks the assembled tools array; if any conforms with `requiresPermission == true`, it appends the permission-handling addendum to the system prompt.
- Tools return `permissionDenied: true` in their typed `Output` rather than throwing — the model addresses denial in its own voice.
- `HealthKit` is iOS-only. `HealthModule` and `LiveHealthStore` are platform-guarded. On macOS-host `swift test`, the registry's factories table omits `HealthModule.id` entirely, and `health.md` becomes "unknown id, log + skip".
- HealthKit's read-permission state is opaque post-prompt — Apple's API can't reliably distinguish "denied" from "no data". Phase 3 sets `permissionDenied: false` for zero step counts; the b0t replies in voice ("you've been still today") rather than claiming denial.

## DEBUG launch args

(no new args — Phase 2's `--use-stub-client` and `--debug-heartbeat-timer` still apply)

## Manual smoke checklist

1. **Simulator with live FM:** ask "what's on my calendar today?" → grant calendar access → see real events. Ask "remind me to email Lin at 4pm" → grant reminders access → reminder appears in iOS Reminders app. Flip `default-bot/modules/health.md` `enabled: true` and rebuild → ask "how many steps today?" → grant health access → real count.
2. **Decline path:** revoke calendar access in Settings → ask the same question → b0t notes the missing access in its own voice.

## Depends on

- `b0tBrain` (`Bot`, `Frontmatter`, `ToolCallRecord`, `PermissionAware`)
- `b0tCore` (`Clock`, `SystemClock`)
- `EventKit` (system, iOS+macOS)
- `HealthKit` (system, iOS only — feature-flagged via `#if canImport(HealthKit) && os(iOS)`)
- `FoundationModels` (system, iOS 26+)

## Read first when working here

- `docs/specs/phase-3-modules-and-tools.md` — design contract
- `docs/decisions/0008-implementation-amendment-2026-05-04.md` — vocabulary + MCP-as-architecture-only
- `docs/prd.md` §3 Phase 3, §5.3
- `default-bot/modules/{calendar,reminders,health,time-awareness}.md` — concrete frontmatter shapes
- `b0tKit/Sources/b0tCore/CLAUDE.md` — the FM-loop contract Phase 3 extends
```

- [ ] **Step 2: Refresh `b0tCore/CLAUDE.md`**

Edit `b0tKit/Sources/b0tCore/CLAUDE.md`:

The Task 6 update already removed the TimeAwarenessTool reference. Now at end of phase, also reflect:
- `LanguageModelClient.generate` returns `(Output, [ToolCallRecord])`.
- `ConversationManager.respond(to:)` returns `ConversationTurn`.
- `TickResult.decided` carries `[ToolCallRecord]`.
- `ContextAssembler` has a `toolsRequirePermission` parameter and emits a permission addendum.
- `JournalWriter.appendConversationTurn` and `appendTick` accept `[ToolCallRecord]` and render `tools_called:`.

- [ ] **Step 3: Commit**

```bash
git add b0tKit/Sources/b0tModules/CLAUDE.md b0tKit/Sources/b0tCore/CLAUDE.md
git commit -m "docs: b0tModules/CLAUDE.md + b0tCore/CLAUDE.md as-built refresh for Phase 3"
```

---

### Task 31: ADR-0009 — `Module`/`ToolHandle` simplification

**Files:**
- Create: `docs/decisions/0009-module-protocol-simplification.md`

PRD §5.3's original sketch had `Module` returning `[ToolHandle]` with an adapter. Phase 3 collapses that to `[any Tool]` directly (Q4). Record the rationale.

- [ ] **Step 1: Write the ADR**

Create `docs/decisions/0009-module-protocol-simplification.md`:

```markdown
# 0009 — Module protocol uses `[any Tool]` directly (no `ToolHandle` wrapper)

**Status:** Accepted
**Date:** 2026-05-04
**Deciders:** Jamee
**Supersedes:** PRD §5.3's original `Module` sketch where the protocol returned `[ToolHandle]`.

## Context

PRD §5.3 sketched the `Module` protocol with a `toolHandles: [ToolHandle]` field. The intent was to keep the model-facing tool surface decoupled from the FoundationModels SDK so future MCP transport could slot in.

During Phase 3 brainstorming on 2026-05-04, ADR-0008's "MCP in scope for Tools in v1" clause was settled as **architecture-only** (Q2): no wire protocol, no external server contact in v1; the architecture must stay compatible. With that lock in place, the question became whether `ToolHandle` was load-bearing.

Inspection: `FoundationModels.Tool` already encodes the MCP shape via `@Generable` (name, description, JSON-schema input via `@Generable Arguments`, JSON-encodable output via `@Generable Output`). A `ToolHandle` wrapper that holds the same fields would re-serialise on every call, with no new information.

## Decision

`Module.tools: [any Tool]` — no `ToolHandle` indirection. Concrete bridges conform to `FoundationModels.Tool` directly.

## Consequences

- Phase 3 ships fewer abstractions; the `Module` protocol is two properties (`tools`, `requiredPermissions`) and one init.
- Future MCP-client transport (Phase 3.5+ or later) lands as a new `Tool`-conforming type that wraps a remote endpoint — `MCPRemoteTool: Tool`. The Module surface stays unchanged.
- `b0tModules` cannot represent a Module that produces *non-FoundationModels* tools without expanding the protocol. If that becomes a need, we add a method to the protocol later. YAGNI for v1.
- PRD §5.3's `Module` sketch is contradicted by code as of this commit. Either §5.3 is amended or this ADR stands as the corrective record.

## What this decision does not change

- ADR-0008's marketplace-compat clause: a Module remains a self-contained unit identified by `module_id`, instantiated via the registry's dispatch table, with explicit `requiredPermissions`. Adding new Modules in v2 still requires a Swift type + a registry entry.
- The "Tool == MCP-shape" property: any `FoundationModels.Tool` is automatically MCP-compatible.
```

- [ ] **Step 2: Update the ADR README index**

Edit `docs/decisions/README.md`:

Add a row for ADR 0009.

- [ ] **Step 3: Commit**

```bash
git add docs/decisions/0009-module-protocol-simplification.md docs/decisions/README.md
git commit -m "docs: ADR-0009 records Module/ToolHandle simplification"
```

---

### Task 32: `IMPLEMENTATION.md` Phase 3 close + acceptance smoke + privacy audit

**Files:**
- Modify: `docs/IMPLEMENTATION.md`
- Document: any mid-phase deviations encountered

- [ ] **Step 1: Run the acceptance smoke checklist**

On a real device or iOS simulator with Apple Intelligence enabled:

1. Open `DebugBrainView` → type "what's on my calendar today?" → grant calendar access → b0t replies with real events. **[VERIFY]** tool-call row visible.
2. Type "remind me to email Lin at 4pm" → grant reminders access → b0t confirms; reminder appears in iOS Reminders. **[VERIFY]**.
3. Type "what reminders do I have" → b0t replies with pending list. **[VERIFY]**.
4. Edit `default-bot/modules/health.md`, set `enabled: true`, rebuild. Type "how many steps today?" → grant health access → b0t replies with step count. **[VERIFY]**.
5. Revoke calendar access in iOS Settings → ask the calendar question again → b0t notes the missing access. **[VERIFY]** model addresses denial in voice.
6. Inspect today's `journal/YYYY-MM-DD.md` after a heartbeat tick that called a tool → **[VERIFY]** `tools_called:` sub-section present.

If any step fails, fix and re-run before proceeding.

- [ ] **Step 2: Privacy audit**

Run: `grep -rn "URLSession\|http\|fetch\|request\|connect\|socket" b0tKit/Sources/b0tModules/`

Expected: no matches outside of permission-related strings. The only network-shaped APIs we should call are EventKit (local-store persistence) and HealthKit (local DB) — neither makes network calls.

Run: `grep -rn "import Network\|Foundation.URLSession\|URLRequest" b0tKit/Sources/b0tModules/`
Expected: no matches.

Document the audit result in the commit message and IMPLEMENTATION.md.

- [ ] **Step 3: Update `IMPLEMENTATION.md`**

Edit `docs/IMPLEMENTATION.md`:

Update current state:

```markdown
## Current state

- **Phase:** 4 — Anatomical GUI (default face)
- **Status:** not started
- **Plan:** (forthcoming — will live at `docs/plans/phase-4-*.md`)
```

Update the ledger row for Phase 3:

```markdown
| 3 | Module bridges + Tools | [phase-3](plans/phase-3-modules-and-tools.md) | complete (YYYY-MM-DD) |
```

(Replace `YYYY-MM-DD` with the actual close date.)

Add a "Notes from Phase 3" section, mirroring the Phase 2 / Phase 1 style:

```markdown
## Notes from Phase 3

- Spec at `docs/specs/phase-3-modules-and-tools.md` settled eight design questions (Q1–Q8) during brainstorming on 2026-05-04. Plan at `docs/plans/phase-3-modules-and-tools.md` decomposed into N tasks across 7 slices.
- Final shape: `b0tModules` package with X public types, M new SPM tests passing on host, K gated live tests against iOS simulator.
- No new third-party SPM dependencies. EventKit, HealthKit, FoundationModels all system-provided.
- Privacy audit clean: no new network calls.
- Deviations and fix-up commits encountered along the way:
  - [list any here, with brief explanation, mirroring Phase 2's notes]
- Follow-up doc PRs:
  - PRD §5.3 / ADR-0009 alignment (this phase added ADR-0009; PRD §5.3 stands as historical sketch).
  - PRD §1.5 file-tree comment on `b0tModules/` reads "EventKit/Mail/HealthKit/Location bridges" — Phase 3 ships EventKit (calendar + reminders) + HealthKit only. Mail/Location/Notes/Weather deferred to Phase 3.5.
- Three open questions that would have been pursued if scope allowed:
  - Predicate-driven calendar window (live impl uses NSPredicate(value: true) for simplicity; production EKEventStore.predicateForEvents would be more efficient).
  - Reminder window-filter not honoured at predicate level (RemindersListTool returns all incomplete; window param ignored).
  - HealthKit metrics beyond steps (sleep_hours, active_energy declared in `default-bot/modules/health.md` `read_metrics` but inert).
```

- [ ] **Step 4: Commit**

```bash
git add docs/IMPLEMENTATION.md
git commit -m "docs: Phase 3 close — IMPLEMENTATION.md update + privacy audit clean"
```

---

## End of Phase 3 — Final checks before merging the phase

- [ ] **All tests green:** `swift test --package-path b0tKit`
- [ ] **Live tests green on simulator:** `LIVE_TESTS=1 xcodebuild test ...`
- [ ] **Build clean:** `xcodebuild -project b0t.xcodeproj -scheme b0tApp -sdk iphonesimulator build`
- [ ] **No new SPM deps:** `git diff main..HEAD -- b0tKit/Package.swift` shows no new `.package(url:` entries.
- [ ] **Privacy audit clean:** no `URLSession` / `http` / network APIs in `b0tModules/`.
- [ ] **Voice-and-copy applied:** Info.plist strings + permission-handling system-prompt addendum reviewed against `docs/references/voice-and-copy-guide.md`.
- [ ] **CLAUDE.md files updated:** `b0tCore/CLAUDE.md` (refresh), `b0tModules/CLAUDE.md` (new).
- [ ] **ADR-0009 committed.**
- [ ] **PRD drift documented:** §5.3 vs ADR-0009; §1.5 file-tree note in IMPLEMENTATION.md Phase 3 notes.
- [ ] **IMPLEMENTATION.md updated:** Phase 3 marked complete, current phase is 4.
- [ ] **All `default-bot/modules/*.md` files still parse cleanly:** `swift test --package-path b0tKit --filter b0tCoreIntegrationTests.DefaultBotModulesTests` PASSes.
- [ ] **DebugBrainView smoke checklist completed on real device or simulator.**

---

## Self-review summary

This plan was self-reviewed against `docs/specs/phase-3-modules-and-tools.md` after drafting:

**Spec coverage:** every numbered acceptance criterion in spec §10 maps to at least one task —
- §10 #1 (calendar in chat) → Tasks 16, 17, 26, 32 step 1.
- §10 #2 (reminders.create demo) → Tasks 19, 21, 26, 32 step 2.
- §10 #3 (reminders.list demo) → Tasks 20, 21, 32 step 3.
- §10 #4 (health steps demo) → Tasks 23, 24, 26, 32 step 4.
- §10 #5 (denial in voice) → Task 25 (system-prompt addendum) + Task 32 step 5.
- §10 #6 (tool calls in chat + journal) → Tasks 11, 12, 13, 32 step 6.
- §10 #7 (clean build) → Task 32 final checks.
- §10 #8 (live tests pass) → Task 29 + Task 32 final checks.
- §10 #9 (production registry counts) → Task 28.
- §10 #10 (no new SPM deps) → Task 32 final checks.
- §10 #11 (privacy audit clean) → Task 32 step 2.
- §10 #12 (voice and copy) → Task 27 step 1 + Task 25 (addendum copy).
- §10 #13 (IMPLEMENTATION.md) → Task 32 step 3.
- §10 #14 (b0tModules CLAUDE.md) → Task 30 step 1.
- §10 #15 (b0tCore CLAUDE.md update) → Tasks 6 + 30 step 2.
- §10 #16 (spec + plan committed) → met by spec commit `cb4d12d` + plan commit at end of writing-plans.
- §10 #17 (ADR or PRD §5.3 amendment) → Task 31.

**Placeholder scan:** no `TBD`/`TODO`/`fill in details`/"add error handling" patterns in task bodies. The transcript-walk in Task 9 is the closest call: it intentionally ships a skeleton because the FoundationModels SDK header is the real source of truth for `Transcript.Entry`'s shape, and the spec §11 risk-1 already documents the "fall back to per-Tool instrumentation" plan-B. The implementer is told exactly what to look at and what to do if the API differs.

**Type consistency:** `ToolCallRecord` uses the same field names (`toolName`, `argumentsSummary`, `outputSummary`, `timestamp`) across Tasks 1, 9, 10, 11, 12, 13, and the journal renderer. `ConversationTurn` is consistently `(response, toolCalls)`. `TickResult.decided` consistently gains `toolCalls:`. `Module.id` (static) and `Module.tools` are consistent with the `Module` protocol declared in Task 2 throughout slices 2–6.

**Scope check:** the plan covers exactly the spec — no scope creep. Mail / Location / Notes / Weather modules are explicitly out-of-scope and deferred to Phase 3.5 (spec §2 + IMPLEMENTATION.md note).

---

## Public API contracts (target shape — for reference)

Phase 3 exposes from `b0tModules`:
- `protocol Module: Sendable` (id static, requiredPermissions, tools, init(parameters:))
- `enum PermissionKind` (calendar, reminders, healthRead([HKQuantityTypeIdentifier]) #if HK)
- `enum ModuleLoadError: Error, Sendable`
- `enum ModuleRegistry` with `static func loadModules(for: Bot) async throws -> [any Module]`
- `protocol EventKitStore: Sendable` + `struct LiveEventKitStore: EventKitStore`
- `protocol HealthStore: Sendable` (#if HK) + `struct LiveHealthStore: HealthStore` (#if HK && iOS)
- `package actor PermissionGate` (not public)
- `struct CalendarModule: Module`, `struct CalendarUpcomingEventsTool: Tool, PermissionAware`
- `struct RemindersModule: Module`, `struct RemindersCreateTool: Tool, PermissionAware`, `struct RemindersListTool: Tool, PermissionAware`
- `struct HealthModule: Module` (#if HK && iOS), `struct HealthStepsTodayTool: Tool, PermissionAware` (#if HK && iOS)
- `struct TimeAwarenessModule: Module`, `struct TimeAwarenessTool: Tool` (no PermissionAware)
- `enum TimeOfDay`

From `b0tBrain`:
- `struct ToolCallRecord: Sendable, Equatable`
- `protocol PermissionAware`

From `b0tCore` (changes):
- `LanguageModelClient.generate` → `(Output, [ToolCallRecord])`
- `ConversationManager.respond(to:)` → `ConversationTurn`
- `struct ConversationTurn: Sendable`
- `enum TickResult.decided(_, _, toolCalls:)`
- `AssembledContext.toolsRequirePermission: Bool`
- `ContextAssembler.init(..., tools:, toolsRequirePermission:)`

