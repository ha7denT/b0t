# b0t — Product Requirements Document

**Document type:** PRD for Claude Code
**Audience:** Claude Code (primary implementer)
**Companion document:** `b0t_design_document.md` (read first for philosophy and design context)
**Status:** v1.0 — implementation spec for v1
**Last updated:** 2026-04-29

---

## 0. How to use this document

This PRD is the implementation contract. The design document is the philosophy. **Read both before starting any major task.** When the PRD and design document conflict, ask the developer (Jamee) — do not silently resolve.

When this document says **REQUIRED**, that is a hard constraint. When it says **SHOULD**, that is a strong default that can be revisited with developer approval. When it says **CONSIDER**, that is guidance.

**Open items** are explicitly marked. Do not silently fill them in — surface them.

---

## 1. Project summary

b0t is a native iOS app that gives users a personal AI companion they can compose, edit, and grow themselves through markdown files. The companion runs entirely on-device using Apple's Foundation Models framework, has a configurable heartbeat for proactive behaviour, and is presented through an anatomical GUI (face, body, organs, wiring, heart).

**One-line pitch:** A personal AI device — issued, not subscribed.

**Price:** AUD $29.99 / USD $19.99 one-time purchase, with a 7-day free trial. No subscription, no ads, no telemetry, no account.

**Platforms:** iPhone (primary). iPad if free from SwiftUI's adaptive layout. macOS / watchOS / visionOS in v2+.

**Minimum OS:** iOS 26 / iPadOS 26. No backwards compatibility.

**Full design context:** see `b0t_design_document.md` for philosophy, aesthetic, and rationale.

---

## 2. Non-negotiables

These decisions are locked. Do not re-open without explicit developer approval.

| # | Decision | Rationale |
|---|---|---|
| 1 | **All AI inference is on-device via Apple Foundation Models.** | Privacy, cost, philosophy. No cloud LLM calls in v1. |
| 2 | **All b0t data is plain markdown files** in the user's Documents directory. | The "you own your b0t" thesis. No proprietary database for b0t content. |
| 3 | **No telemetry, no analytics, no tracking.** App Store privacy manifest declares zero tracking. | Privacy is a feature. |
| 4 | **iOS 26+ only.** Aggressive Liquid Glass adoption where it serves the cassette-futurism aesthetic; do not add availability guards for older OSes. | Single-target codebase. |
| 5 | **Heartbeat uses BGAppRefreshTask + event triggers.** | iOS background reality. No silent fallback to fake heartbeats. |
| 6 | **One-time purchase via non-consumable IAP, with 7-day trial tracked locally.** | No subscription. |
| 7 | **All UI copy follows the cassette-futurism voice guide** (see design document §11). | Aesthetic discipline. |
| 8 | **Multi-b0t enforces single-active-heartbeat. Soft-cap at 6 b0ts.** | iOS background budget reality + user attention model. |
| 9 | **No raw-RGB colour pickers.** All b0t colour customisation goes through curated palettes. | Aesthetic discipline. |
| 10 | **No emoji or whimsy accoutrements in Face Creator.** Issued-equipment aesthetic only. | Aesthetic discipline. |

---

## 3. Architecture

### 3.1 Project structure

A modular Swift Package monorepo. Shared logic in packages, app target imports them.

```
b0t/
├── b0t.xcodeproj
├── b0tKit/                              # Swift Package — shared logic
│   ├── Package.swift
│   └── Sources/
│       ├── b0tCore/                     # Foundation Models loop, heartbeat, agent state
│       ├── b0tBrain/                    # Markdown file system, parsing, frontmatter, linking
│       ├── b0tModules/                  # Module registry, EventKit/Mail/HealthKit/Location bridges
│       ├── b0tFace/                     # Face rig, animation, rendering
│       ├── b0tAudio/                    # AVAudioEngine pipeline, TTS effects
│       └── b0tDesign/                   # Tokens, palettes, fonts, shared views
├── b0tApp/                              # iOS target
│   └── Sources/
│       ├── App/                         # App entry, scene, environment
│       ├── Home/                        # Anatomical GUI, chat surface
│       ├── Inspect/                     # Organ inspection (.md viewer)
│       ├── Edit/                        # Markdown editor (full-screen)
│       ├── FaceCreator/                 # Face composition tool
│       ├── Gallery/                     # Multi-b0t selector
│       ├── Heartbeat/                   # Heartbeat config sheet
│       └── Onboarding/                  # First-60-seconds and 24-beat tutorial
├── default-bot/                          # source-of-truth for the shipped b0t (markdown)
│   ├── identity/
│   ├── memory/
│   ├── modules/
│   ├── heartbeat/
│   └── face/
├── assets/                               # face parts, palettes, fonts, icons, sounds
│   ├── face-parts/
│   ├── palettes/
│   ├── sounds/
│   ├── fonts/
│   └── icons/
└── Tests/
    ├── b0tCoreTests/
    ├── b0tBrainTests/
    ├── b0tModulesTests/
    └── b0tAudioTests/
```

**Resource bundling.** `default-bot/` and `assets/` live at the repo root, not under a `Resources/` group. The iOS app target adds them as **folder references** in the Xcode project (`b0tApp` → "Add Files to b0tApp" → check "Create folder references"). Folder references mirror the on-disk structure in the bundle, so files added to `default-bot/modules/` on disk are automatically included in the next build. No symlinks, no copy-build-phase scripts.

**Why:** the shared kit makes a future macOS/watchOS port low-cost. The brain layer is independent of the GUI — the markdown system can be unit-tested without launching SwiftUI.

### 3.2 Data flow

```
User ←→ Home View ←→ ConversationManager ←→ b0tCore.LanguageModelSession
                          │
                          ↓
                    b0tBrain (reads/writes .md files)
                          │
                          ↓
                    b0tModules (calls EventKit, Mail, HealthKit, etc.)
                          │
                          ↓
              Foundation Models @Generable typed responses
                          │
                          ↓
                    Heartbeat journal (writes journal/YYYY-MM-DD.md)
```

A heartbeat tick is the same flow without a user prompt — the heartbeat manager wakes via `BGAppRefreshTask`, runs through the same pipeline, surfaces output as a notification or stored journal entry.

### 3.3 The Foundation Models session pattern

Every interaction is a fresh `LanguageModelSession`. Sessions are short-lived. State persists in markdown files, not session memory.

```swift
// pseudocode
func runTick(forBot bot: Bot) async throws -> TickResult {
    let context = try await ContextAssembler.assemble(
        bot: bot,
        identityFiles: [.core, .voice],
        memoryFiles: [.core, .recent],
        moduleFiles: bot.modules.relevantToCurrentContext(),
        recentJournal: bot.journal.lastN(5),
        tokenBudget: 3500  // leave room for response
    )
    
    let session = LanguageModelSession(
        instructions: context.systemPrompt,
        tools: bot.modules.toolHandles
    )
    
    let decision: TickDecision = try await session.respond(
        to: context.userPrompt,
        generating: TickDecision.self
    )
    
    try await Executor.apply(decision, for: bot)
    try await JournalWriter.append(decision, to: bot.todaysJournal)
    return TickResult(decision: decision)
}
```

`TickDecision` is `@Generable` — the model returns a typed Swift struct, not free text. Same pattern for all major LLM interactions.

### 3.4 Context budgeting

The 4096-token Foundation Models context window is the hardest constraint. Strict policy:

- `identity/core.md` + `identity/principles.md`: ~450 tokens, always loaded
- `memory/core.md`: ~150 tokens, always loaded
- 1–3 relevant module files: ~600 tokens
- Recent journal (last 3–5 entries): ~400 tokens
- Working transcript: ~1500 tokens, auto-truncated
- Response budget: ~500 tokens
- Buffer: ~500 tokens

`identity/about_b0t.md`, `memory/about_me.md`, full `memory/recent.md`, and `memory/archive/` are loaded *only on demand* via tool call when the user asks meta questions or specific recall is needed. They are never in the always-loaded set.

The `ContextAssembler` is responsible for staying under budget. **REQUIRED:** every assembled prompt logs its token count in debug builds. **REQUIRED:** if assembly exceeds budget, the assembler logs which file pushed it over and falls back to a more aggressive memory digest.

### 3.5 Persistence

- **b0t files:** plaintext on disk in `Documents/b0ts/`. Never serialised to a binary format. The user can open them in any text editor.
- **App preferences and trial state:** `UserDefaults` for non-sensitive prefs, Keychain for trial-start date and IAP receipt validation.
- **Per-device only.** No iCloud Drive sync in v1. Each device has its own b0ts. Users who want to move a b0t between devices use manual export/import (a button that produces a `.zip` of the b0t directory, shareable via AirDrop/Files/Mail; counterpart import button accepts a zip and creates a new b0t entry).
- **No SwiftData / Core Data for b0t content.** SwiftData *may* be used for ephemeral caches (parsed-markdown cache, animation state) but never as the source of truth.

### 3.6 Background execution

- **Heartbeat:** `BGAppRefreshTask`, scheduled at the configured BPM as a target. The OS may delay or skip; this is honest and surfaced in the UI.
- **Event triggers:** Significant Location Change, Calendar event approaching (via UNNotificationCategory), Focus changes, app foregrounding. Each fires a heartbeat tick with the relevant trigger context.
- **Notifications:** `UserNotificationCenter` with custom service extension for mood-variant face icons.

**REQUIRED:** the heartbeat manager logs every wake (timestamp, trigger source, success/failure) to the journal. **REQUIRED:** if iOS skips beats, the next successful beat detects the gap and the b0t can comment on it.

---

## 4. Implementation phases

These are ordered. Each phase produces a buildable, testable artefact. Do not skip ahead.

### Phase 0 — project setup
- Create Xcode project with the structure in §3.1.
- Configure Swift Package, targets, code signing.
- Add MCP configurations (see §10).
- Establish CI: `xcodebuildmcp` build-and-test on push.
- Add `CLAUDE.md` files at root and in key subdirectories (see §10.4).
- **Acceptance:** project builds clean. Empty SwiftUI app launches on simulator.

### Phase 1 — markdown brain (no LLM yet)
- Implement `b0tBrain`: file system access, markdown parsing, frontmatter parsing, inter-file linking, backlink computation.
- Define the canonical b0t directory structure (see design doc §2.1).
- Ship the default b0t resources (identity files, default modules, empty memory files, empty journal).
- Implement `BotLoader` that reads a b0t directory into memory and `BotWriter` that persists changes.
- **Acceptance:** unit tests load the default b0t, parse all files, navigate links, write modifications. No UI needed.

### Phase 2 — Foundation Models loop
- Implement `b0tCore`: `ContextAssembler`, `LanguageModelSession` wrapper, `TickDecision` and other `@Generable` types.
- Implement the conversation flow (user prompt → context → typed response → applied effects).
- Implement the heartbeat tick flow with `BGAppRefreshTask` registration.
- Wire to the markdown brain for state persistence.
- Implement journal writing in adapted-OpenClaw format.
- **Acceptance:** a CLI test harness or minimal SwiftUI view can hold a conversation with the default b0t. Heartbeats fire and write journal entries.

### Phase 3 — Module bridges + Tools
- Implement `b0tModules`: typed bridges to EventKit, Mail (read-only via MailKit if available, else `MFMailComposeViewController` for compose), HealthKit, Core Location, Notes (via NotesKit if available, else surface limitation), Reminders (EventKit).
- Each bridge is a Swift type that exposes tool handles to the model and is permission-gated.
- Implement module registration: each shipped module `.md` declares its `module_id` in frontmatter, which maps to a registered bridge.
- **Acceptance:** the b0t can read calendar, surface upcoming events, create reminders, comment on step count. Permissions are requested correctly.

### Phase 4 — Anatomical GUI (default face)
- Implement `Home/`: face area (top half), organ ring (around face), heart (centre below face), chat surface (bottom half).
- Implement organ wiring with phosphor-glow lines, animated based on system activity.
- Use a default rigged face (one shipped face) for now — Face Creator is later.
- Implement chat composer.
- Implement organ tap → inspection mode (lower half shows .md content).
- Implement edit mode (full-screen markdown editor with frontmatter controls).
- **Acceptance:** the default b0t is alive on screen, breathing, with a beating heart. The user can chat, tap organs to inspect them, edit files. Wiring lights up when modules are used.

### Phase 5 — Onboarding sequence (first 60 seconds + 24-beat tutorial)
- Implement the first-60-seconds scripted sequence (see design doc §6).
- Implement the 24-beat onboarding sequence as a special module.
- Implement Face Creator entry point at the third wow moment.
- **Acceptance:** fresh install plays through the first-60-seconds sequence smoothly. The 24-beat tutorial fires across subsequent heartbeats.

### Phase 6 — Face Creator
- Implement the parts + overlays + accoutrements composition system.
- Implement palette system (curated, no RGB picker).
- Implement face rig with animation states (idle, speaking, thinking, surprised, sleepy, attentive, worried, delighted).
- Implement Randomise / shuffle.
- Implement face export as the b0t's `face/` directory contents (parameter file + composed sprite cache).
- Pre-render mood-variant icons for notifications.
- **Acceptance:** user can compose, save, and revisit a custom face. The home screen shows the user's face. Notifications use the right mood variant.

### Phase 7 — Multi-b0t and Gallery
- Implement multi-b0t directory model with `_active` pointer.
- Implement Gallery view (wallet-style selector).
- Implement b0t switching (deliberate gesture, friction).
- Implement dormant-b0t conversation (any b0t can be opened and chatted with; only active has heartbeat).
- Soft-cap at 6 b0ts.
- **Acceptance:** user can create up to 6 b0ts, switch between them, converse with dormant ones, only the active one has a heartbeat firing in the background.

### Phase 8 — Audio (TTS + effects)
- Implement `b0tAudio`: `AVSpeechSynthesizer` piped through `AVAudioEngine` effect chain.
- Implement 8 audio filters: Clean, Warm, Tape, FM, Radio, Distant, Vintage, Hi-Fi.
- Add filter selection to b0t's `identity/audio.md` file.
- Add UI sound effects (clicks, thunks, transitions) — restrained, OP-1 sensibility.
- **Acceptance:** the b0t can speak, with a distinct audio character per filter. UI sounds feel coherent with the aesthetic.

### Phase 9 — IAP and trial
- Implement non-consumable IAP for full unlock.
- Implement local trial-start tracking with Keychain persistence.
- Implement soft paywall: trial expiry stops heartbeats, leaves files and chat intact.
- Implement App Store receipt validation.
- Implement Family Sharing.
- Implement restore purchases.
- **Acceptance:** trial flow works end-to-end. Trial expiry stops the heart visually and functionally. Purchase reactivates everything immediately.

### Phase 10 — polish and ship
- Accessibility pass: VoiceOver, Dynamic Type, reduce-motion alternatives, haptic-only mode for deaf/HoH users.
- Performance pass: frame rate audits during animation, memory profiling, battery impact.
- Privacy manifest, App Store metadata, screenshots, marketing video.
- TestFlight beta with real users.
- App Store submission.
- **Acceptance:** App Store approval and launch.

---

## 5. Detailed component specifications

### 5.1 b0tBrain (markdown layer)

**REQUIRED:** all parsing must be lossless — load → save round-trip preserves whitespace, comments, ordering of frontmatter keys.

**REQUIRED:** frontmatter parser supports YAML scalars, lists, and nested objects sufficient for the file types in §2.1 of the design doc. Use a vetted YAML library (CYaml or Yams) — do not roll our own.

**REQUIRED:** markdown links of the form `[label](relative/path.md)` are routed through an in-app handler when tapped, opening the relevant file in the inspection layer. External http(s) links open in Safari.

**SHOULD:** support Obsidian-style wikilinks `[[path/file]]` as a secondary syntax, rendered in inspection mode but normalised to standard markdown links when the user explicitly edits.

**REQUIRED:** the brain layer does not hold a permanent in-memory model — files are read on demand and cached via `NSCache` with explicit invalidation when the file changes on disk.

### 5.2 b0tCore (Foundation Models loop)

**REQUIRED:** every `LanguageModelSession` is short-lived. Do not retain sessions across user turns.

**REQUIRED:** all major model interactions use `@Generable` typed output. Specific types to define:
- `TickDecision` — heartbeat tick output (action, organ_used, journal_entry, memory_update)
- `ConversationResponse` — chat reply (text, mood, tool_calls)
- `MemoryObservation` — when b0t notices something to remember (about_who, what, importance)
- `RelationshipNote` — when b0t learns about a person (name, relation, notes)
- `MoodTransition` — face mood changes (from, to, why)

**REQUIRED:** `ContextAssembler` produces a typed `AssembledContext` with fields for each component (identity, memory, modules, recent journal). The system prompt is built from this struct, never concatenated ad-hoc.

**REQUIRED:** if `Foundation Models` returns `.exceededContextWindowSize`, gracefully start a new session with the current state digest and surface the event to the user via the b0t ("oh — let me start fresh, I was getting muddled").

**SHOULD:** instrument every model call with a debug-build-only metric: tokens-in, tokens-out, latency, decision type. Used for development tuning.

### 5.3 b0tModules (capability bridges)

Each module bridge is a Swift type conforming to `Module`:

```swift
protocol Module {
    static var id: String { get }
    var requiredPermissions: [PermissionKind] { get }
    var toolHandles: [ToolHandle] { get }
    func loadParameters(from frontmatter: Frontmatter) throws
}
```

**REQUIRED:** module `.md` files declare `module_id` in frontmatter; loader matches to registered Swift type.

**REQUIRED:** every module that requires a system permission (calendar, mail, health, location) requests permission through standard iOS APIs at first use. Module is disabled in UI until permission granted. b0t can comment on missing permissions ("I don't have access to your calendar — can you let me look?").

**REQUIRED:** v1 ships exactly the modules listed in design doc §4.2. No more, no fewer.

### 5.4 b0tFace (rig + rendering)

**REQUIRED:** the face is rendered using **SpriteKit embedded in SwiftUI via `SpriteView`**. Each face part is an `SKSpriteNode`. Animation is driven by `SKAction` sequences (idle blink, breathing, glance, mood transitions). Sprite frames are bundled in `SKTextureAtlas` per part. Mood states are state-machine-driven on the scene level.

**Why SpriteKit + SwiftUI:** native Apple frameworks (per project goals), full code-level access for Claude Code (every animation parameter, sequence, and state is in Swift, diffable in git, editable by the agent), pixel-perfect nearest-neighbour rendering out of the box, mature sprite-atlas tooling. Trade-off: more code than a Rive `.riv` import would be for the same animation, but every line is editable and reviewable.

**REQUIRED:** every shipped face part has all 8 mood states baked in (idle, speaking, thinking, surprised, sleepy, attentive, worried, delighted). New parts added later must conform to the same animation-state contract.

**REQUIRED:** the face renders at native resolution scaled for retina displays without losing the pixel-art grid. Use nearest-neighbour scaling (`SKTexture.filteringMode = .nearest`), never bilinear.

**SHOULD:** add CRT/scanline overlay as an `SKEffectNode` with a fragment shader, user-toggleable in settings. Default: on, very subtle.

**Pixel-art assets are provided by the developer (Jamee)** — sourced from a purchased kit, custom design, or a combination. Claude Code does not generate assets; it integrates them.

### 5.5 b0tAudio (TTS pipeline)

**REQUIRED:** TTS uses `AVSpeechSynthesizer` writing to a buffer (`write(_:toBufferCallback:)`), routed through `AVAudioEngine` with a chain of `AVAudioUnit` effects per filter.

**Filter specifications (REQUIRED, exact parameters open for tuning):**
- Clean: passthrough.
- Warm: subtle low-pass, soft EQ boost in low-mids.
- Tape: pitch wobble (~0.5% LFO), low-pass (~6kHz cutoff), gentle saturation, very subtle wow-and-flutter.
- FM: high-pass (~300Hz), narrow bandpass, slight distortion, mono.
- Radio: bandpass (~400Hz–4kHz), light noise floor, transmission artefacts.
- Distant: heavy reverb, low-pass, reduced amplitude.
- Vintage: bit reduction, slight aliasing, warm EQ.
- Hi-Fi: clean with subtle stereo enhancement and gentle harmonic excitement.

**REQUIRED:** filter is selected per b0t and persisted in `identity/audio.md` frontmatter.

**REQUIRED:** TTS is disabled by default. User explicitly enables in b0t settings. Aesthetically, b0t is text-first; voice is opt-in.

### 5.6 Heartbeat manager

**REQUIRED:** registers `BGAppRefreshTask` at app launch with the bundle's task identifier.

**REQUIRED:** at each tick: load active b0t, read `heartbeat/schedule.md` and `heartbeat/actions.md`, check quiet hours, run a tick if conditions met, schedule the next tick.

**REQUIRED:** every tick (whether successful, skipped, or errored) writes to the journal.

**REQUIRED:** on missed beats (gap detected at next successful tick), b0t can surface this in conversation.

**REQUIRED:** the heart UI element shows real-time beating at the configured BPM. When heartbeats are paused (trial expired, app set to quiet, etc.), the heart is visibly still and a small status text explains why.

### 5.7 Onboarding

**REQUIRED:** the first-60-seconds sequence is hand-scripted, not generated. Implement as a deterministic state machine. The b0t's words at this stage are written by humans, not produced by the LLM. After onboarding, the LLM takes over.

**REQUIRED:** the 24-beat tutorial sequence is a special module (`modules/onboarding.md` in the default b0t). The module emits the next tutorial heartbeat each beat until complete or dismissed.

**REQUIRED:** onboarding can be skipped at any point. Users who skip are not nagged.

### 5.8 Notifications

**REQUIRED:** every notification carries the active b0t's face in the appropriate mood as the icon, via `UNNotificationServiceExtension` and `UNNotificationAttachment`.

**REQUIRED:** mood variants (~6-8) are rendered to disk at face-creation time and cached.

**REQUIRED:** notification budget — default cap of 5 per day per b0t, user-adjustable. Hard cap of 20.

**REQUIRED:** notifications respect Focus modes and quiet hours.

---

## 6. Voice and copy guide

All app copy must follow these rules. **Run any user-facing string through this filter before shipping.**

**System messages (errors, status, settings labels):** all-lowercase. Functional. Period appropriate. No exclamation marks. No emoji.

| Avoid | Use |
|---|---|
| "Oops! Something went wrong." | "heartbeat unavailable. retrying." |
| "Welcome to b0t!" | "device ready." |
| "Connect your account." | "request access — calendar." |
| "Subscribe to continue." | "extend operation? activation required." |
| "Settings" | "configuration" |
| "Your data is safe with us." | "all files local. no transmission." |

**The b0t's own conversation:** sentence-case. Warm. Specific. Avoids cliché AI mannerisms. Never says "As an AI…" Never apologises performatively. Has opinions when asked. Asks questions when curious. Is comfortable with silence.

**Marketing / App Store / website:** sentence-case, slightly more polished, but still recognisably the b0t voice. Never marketing-superlative ("Revolutionary AI companion!"). Always specific and grounded.

---

## 7. Privacy

- **App Store privacy manifest:** declares zero tracking, zero data collection, zero linked data.
- **No analytics, no telemetry, no crash reporting that ships data off-device.** If crash logging is needed, use Apple's built-in MetricKit which keeps data on-device unless the user explicitly shares.
- **All system permissions** (calendar, mail, health, location, notifications) are requested only when the user enables a module that needs them, with explicit explanations.
- **No ad SDK, no third-party SDKs that phone home.** Third-party Swift packages must be audited for network calls before inclusion.
- **iCloud Drive sync is opt-in,** with the disclosure that files will sync to the user's iCloud (under their Apple ID, never to b0t servers).

---

## 8. Accessibility

- **VoiceOver:** every interactive element has a meaningful label. The face has a label that describes the b0t's current expression.
- **Dynamic Type:** all chat and inspection text scales to user's preferred size.
- **Reduce Motion:** if enabled, the face's idle animations slow significantly and the wiring pulses are simplified.
- **Reduce Transparency:** the privacy shield and CRT overlays use opaque alternatives.
- **Haptic-only mode:** users who can't hear can opt in to haptic feedback for all UI sounds.
- **Voice Control:** all primary interactions are voice-controllable.

**REQUIRED:** accessibility is a v1 requirement, not a polish item. Tested before submission.

---

## 9. Out of scope for v1

Do not implement these without explicit developer approval:

- macOS, watchOS, visionOS apps
- Online module repository / marketplace
- Inter-b0t messaging
- Cloud LLM fallback
- Voice-first interaction (always-on listening)
- Personal Voice TTS integration
- LoRA adapter fine-tuning
- Live Activities and Dynamic Island integration (deferred to v1.1 unless trivial)
- iPad-specific UI (use SwiftUI's adaptive layout, but do not design dedicated iPad views)
- Apple Pencil support
- Shortcuts integration
- Widgets (deferred to v1.1)
- Lock Screen integration
- Background voice input

---

## 10. Tooling and Claude Code workflow

### 10.1 Required MCP servers

Two MCP servers must be configured for Claude Code:

**Apple's native Xcode MCP** (Xcode 26.3+, ships with Xcode):
```bash
claude mcp add --transport stdio xcode -- xcrun mcpbridge
```
Provides 20 tools including `RenderPreview` (SwiftUI preview rendering — Claude Code can see UI changes), `DocumentationSearch` (semantic search across Apple docs and WWDC transcripts), file ops, and Swift REPL.

**XcodeBuildMCP** (third-party, standalone):
```bash
claude mcp add XcodeBuildMCP npx -- -y xcodebuildmcp@latest mcp
```
Provides 59 tools for builds, tests, simulators, real devices, LLDB debugging, UI automation. Works without Xcode running.

**Why both:** complementary capabilities. Apple's MCP gives Claude Code access to Xcode's IDE features (previews, semantic search). XcodeBuildMCP gives headless build/test/simulator control. Most workflows benefit from both available.

### 10.2 Slash commands

The repo ships with these slash commands in `.claude/commands/`:
- `/build` — XcodeBuildMCP build to default simulator.
- `/test` — XcodeBuildMCP run all tests.
- `/preview <view>` — Apple MCP `RenderPreview` for the named SwiftUI view.
- `/fix-build` — XcodeBuildMCP build with ultrathink, propose and apply fixes.
- `/implement <feature>` — PRD-driven feature implementation.
- `/audit` — codebase audit for App Store submission readiness.

### 10.3 Hooks

- **Pre-commit:** SwiftLint via `swift-format` runs and must pass.
- **Pre-PR:** all tests pass via XcodeBuildMCP.

### 10.4 CLAUDE.md scaffolding

The project ships with CLAUDE.md files at multiple levels:

**Root `CLAUDE.md`:** project overview, build instructions, architecture summary, link to design doc and PRD, environment detection (Xcode-bundled Claude vs. standalone Claude Code).

**Per-package CLAUDE.md** (in `b0tCore/`, `b0tBrain/`, `b0tModules/`, etc.): describes that package's responsibilities, public API contracts, and patterns to follow.

**`Resources/CLAUDE.md`:** describes the structure of the default b0t resources, the module format, and how to add new shipped modules.

These CLAUDE.md files are loaded automatically by Claude Code in each working context.

### 10.5 Workflow expectations

- **Read the design doc and PRD before any major task.** Re-read when scope shifts.
- **Use Apple's Foundation Models documentation** (via `DocumentationSearch`) as the source of truth for the framework. The framework is new and evolving; do not rely on memory.
- **Use `RenderPreview`** to verify UI changes visually. Do not assume; verify.
- **Surface ambiguity, don't resolve silently.** When the PRD is unclear or contradicts the design doc, ask the developer.
- **One concern per commit.** Atomic, reversible, with clear commit messages.
- **Tests are not optional.** Every new public API in `b0tKit` ships with tests. UI views ship with snapshot tests where feasible.
- **Performance is a feature.** Frame rate audits, memory checks, battery impact considered as part of acceptance.

---

## 11. Acceptance criteria for v1.0 release

The v1.0 release ships when all of these are true:

- [ ] All 10 implementation phases complete.
- [ ] All non-negotiables in §2 honoured.
- [ ] App passes `xcodebuildmcp test` with full coverage of `b0tKit`.
- [ ] Frame rate during home-screen idle stays at 60fps on iPhone 16 Pro and 14 Pro.
- [ ] Battery impact: less than 5% per day of background heartbeat at default BPM, measured on iPhone 14 Pro.
- [ ] Memory: app idle holds under 150MB.
- [ ] First-60-seconds sequence completes smoothly on cold install in under 10 seconds to "talk / hang out" prompt.
- [ ] Foundation Models response latency: median first-token under 800ms on iPhone 15 Pro.
- [ ] All accessibility requirements in §8 met.
- [ ] App Store privacy manifest declares zero tracking, validated.
- [ ] TestFlight beta with at least 20 real users for 14 days, with feedback addressed.
- [ ] Marketing assets (screenshots, video, App Store description) approved by developer.
- [ ] Pricing and IAP flow tested end-to-end including Family Sharing and restore.

---

## 12. Open questions to resolve before / during implementation

These are explicitly open. Do not silently fill them in.

| # | Question | Block phase | Status |
|---|---|---|---|
| 1 | Final pricing. Decided pre-launch. | Phase 9 | Open |
| 2 | Default `identity/core.md` content. | Phase 1 | **Resolved** — drafted, in revision |
| 3 | Face rigging tool. | Phase 4 | **Resolved** — SpriteKit + SwiftUI |
| 4 | Pixel art assets. | Phase 4 | **Resolved** — provided by Jamee (kit + custom) |
| 5 | Curated palette count. | Phase 6 | **Resolved** — 12 palettes in v1 |
| 6 | Type choices. | Phase 4 | **Resolved** — IoskeleyMono NL (brain, open-source), Söhne (chat). |
| 7 | Sound design source. | Phase 8 | **Resolved** — internal |
| 8 | Mail framework access vs `MFMailComposeViewController`. | Phase 3 | Open |
| 9 | Notes integration approach. | Phase 3 | **Resolved** — fall back to Shortcuts integration or skip module in v1 |
| 10 | App icon direction. | Phase 10 | **Resolved** — the heart organ from within the app |
| 11 | Marketing video direction. | Phase 10 | Open |

### 12.1 Locked decisions (do not re-open)

- **Per-device storage only.** No iCloud Drive sync in v1. Manual export/import via shareable `.zip` of the b0t directory.
- **`identity/core.md` is split** into `core.md` (voice anchor, always loaded), `principles.md` (safety contract, always loaded), `about_b0t.md` (manual, loaded on demand). See PRD §3.4 and design doc §5.1.
- **Default b0t name is `b0t-01`.** New b0ts created by the user follow `b0t-NN` numbering with randomised default faces. User can rename at any time.

Each remaining open item has a placeholder default that the developer (Jamee) will resolve. Surface them in the relevant phase; do not silently choose.

---

## 13. Definition of done — for any task

Any individual task is done when:

1. Code compiles with no warnings (treat warnings as errors).
2. Tests cover the new behaviour and pass.
3. UI changes verified with `RenderPreview`.
4. Voice-and-copy guide (§6) followed for any user-facing string.
5. Cassette-futurism aesthetic respected for any visual change.
6. Privacy posture preserved — no new network calls, no new tracking.
7. Performance impact understood — frame rate, memory, battery.
8. CLAUDE.md updated if the change affects how future tasks should be approached.
9. PR description references the relevant PRD section and any closed open-questions.

---

*end of PRD.*
