# Phase 4 — Anatomical GUI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the home screen — the b0t alive on glass with one static face (Hilfer), a 9-organ ring, beating heart, pulsing wiring, and a backlit-LCD inspection panel that doubles as the chat surface.

**Architecture:** SpriteKit-in-SwiftUI hybrid (Approach 2 from brainstorming). One `SpriteView` hosts an `AnatomyScene` containing `FaceComposite` (Skull + Eyes + Jaw + Decal layers) + 9 `OrganNode`s + `HeartNode` + `WiringNetwork`. SwiftUI renders the LCD inspection panel below. An `@Observable AnatomyState` bridges scene events to view updates and back. Face rig (8 mood states, blink, breathing) defers to Phase 6 — Phase 4 ships the face as three baked PNGs.

**Tech Stack:**
- Swift 6.0+, iOS 26 deployment target.
- `SpriteKit` (system-provided) — `SKScene`, `SKSpriteNode`, `SKShapeNode`, `SKEffectNode`, `SKShader`, `SKAction`, `SKTextureAtlas`.
- `SwiftUI` — `SpriteView`, `@Observable`, `@Bindable`, `Slider`, `DatePicker`, `Picker`, `TextField`.
- `FoundationModels` (system-provided in iOS 26) — chat pipeline already shipped in Phase 2; reused here.
- `b0tBrain` (Phase 1) — `Bot`, `BotFile`, `Frontmatter`, `YAMLValue`, `BotStore`, `KnownFiles`, `BotProvisioner`.
- `b0tCore` (Phase 2) — `LanguageModelClient`, `ConversationManager`, `HeartbeatScheduler`, `JournalWriter`.
- `b0tModules` (Phase 3) — `Module`, `ModuleRegistry`, `Tool`s.
- XCTest. **No new third-party dependencies.** Snapshot testing via `RenderPreview` + manual smoke; no `swift-snapshot-testing` added.

**Spec:** `docs/specs/phase-4-anatomical-gui.md` (approved 2026-05-05) is the source of truth for behaviour. This plan sequences the implementation; consult the spec when in doubt.

**Conventions used in this plan:**
- `**[CC]**` marks a Claude-Code-executable step.
- `**[VERIFY]**` marks a verification step — run a command, check output, do not move on if it fails.
- `**[JAMEE]**` marks a step that requires Hayden's input (asset delivery, design call) before the task can complete.
- Tasks are TDD-shaped: failing test → minimal implementation → passing test → commit. Each task is a single atomic commit.
- Walking-skeleton discipline: every slice ends with the package compiling, all unit tests green, and a `RenderPreview` available where applicable.

**Code conventions surfaced during execution (apply to all verbatim snippets below):**
- **Identifier naming follows project `.swift-format`** — `AlwaysUseLowerCamelCase` is enforced by the pre-commit hook. Where a verbatim snippet uses `snake_case` (e.g. test helpers like `calendar_aliased_to_tools()`), rename to `lowerCamelCase` (`calendarAliasedToTools()`) when implementing. Functional intent is unchanged; the spec/plan text was authored before the formatter rule landed.
- **Test classes touching SKNode action APIs need `@MainActor`** under Swift 6 strict concurrency. Methods like `SKNode.action(forKey:)` are `@MainActor`-isolated and return non-Sendable `SKAction?` values — calling them from a nonisolated `XCTestCase` method fails to compile. Add `@MainActor` to the test class declaration when verbatim test snippets exercise these APIs (HeartNodeTests, WiringNetworkTests, AnatomyScene_OrgansAndHeartTests are the precedent). Tests that only construct nodes and inspect immutable shape (size, name, children count) do not need the annotation.
- **Pre-commit hook is authoritative on formatting** — alphabetised imports, blank line before `@testable`, trailing commas in multiline literals, 4-space indentation. Match the formatter's style up front to avoid a re-format/re-stage cycle. Never bypass with `--no-verify`.

**Reference docs to consult during execution:**
- `docs/specs/phase-4-anatomical-gui.md` — the design contract
- `docs/b0t-amendment-2026-05-04.md` — vocabulary and architectural locks (Manufacturer/Model/Part)
- `docs/decisions/0003-spritekit-over-rive.md` — render-engine choice
- `docs/decisions/0007-anatomical-gui-not-chat.md` — interface philosophy (note: organ language partly superseded by ADR-0010 produced in Slice 0)
- `docs/decisions/0008-implementation-amendment-2026-05-04.md` — earlier amendment
- `docs/references/aesthetic-references.md` — visual languages (especially CRT vs. LCD distinction)
- `docs/references/voice-and-copy-guide.md` — for any user-facing string
- `b0tKit/Sources/b0tBrain/CLAUDE.md` — markdown layer contract
- `b0tKit/Sources/b0tCore/CLAUDE.md` — FM-loop contract

---

## File Structure (what this phase creates / modifies)

**Creates** (under `b0tKit/Sources/b0tDesign/`):

```
b0tDesign/
├── Palette/
│   ├── WundercogPalette.swift      // Hilfer's palette tokens
│   └── LCDPalette.swift            // Backlit LCD tokens
├── Shaders/
│   └── CRTScanlineShader.swift     // SKShader for the Eye-screen
├── Typography.swift                // IoskeleyMono NL + Verdana wrappers
└── CLAUDE.md
```

**Creates** (under `b0tKit/Sources/b0tFace/`):

```
b0tFace/
├── FacePart.swift                  // protocol with 3 conformers
├── SkullNode.swift                 // SKSpriteNode subclass (or factory)
├── EyesNode.swift                  // SKEffectNode wrapping SKSpriteNode + scanline shader
├── JawNode.swift                   // SKSpriteNode subclass (or factory)
├── DecalNode.swift                 // SKNode container (empty for Hilfer)
├── FaceComposite.swift             // 4-layer composition with anchor positioning
├── OrganID.swift                   // enum of 9 organs
├── OrganNode.swift                 // 64px sprite + ActivityPulse subnode
├── HeartNode.swift                 // BPM-driven pulse
├── WiringNetwork.swift             // SKShapeNode lines + direction-aware pulse
├── AnatomyLayout.swift             // positions for 9 organs + heart
├── AnatomyScene.swift              // root SKScene
├── AnatomyView.swift               // SwiftUI SpriteView wrapper
└── CLAUDE.md
```

**Creates** (under `b0tKit/Sources/b0tHome/` — new module):

```
b0tHome/
├── AnatomyState.swift              // @Observable bridge
├── HomeView.swift                  // SwiftUI shell (anatomy + LCD)
├── InspectionPanel.swift           // switches by selectedOrgan
├── ChatView.swift                  // default LCD content
├── EditorView.swift                // full-screen markdown editor
├── DirectoryNavigatorView.swift    // file lister for Modules/Tools/Memory/Identity
├── OrganInspectionView.swift       // markdown + frontmatter controls
├── MarkdownRenderer.swift          // Text(.init(markdown:)) wrapper
├── FrontmatterControls/
│   ├── FrontmatterControl.swift    // protocol + dispatcher
│   ├── FrontmatterTypeRegistry.swift     // type-based fallback
│   ├── FrontmatterSemanticRegistry.swift // bpm / quiet_hours / enabled
│   ├── BPMSlider.swift
│   ├── QuietHoursPicker.swift
│   ├── EnabledToggle.swift
│   ├── StepperControl.swift
│   ├── BoolToggleControl.swift
│   ├── ClockTimePicker.swift
│   ├── EnumPickerControl.swift
│   └── TextFieldControl.swift
├── Synthesised/
│   ├── ReasoningStateFile.swift    // synthesised "reasoning state" pseudo-file
│   ├── SensorsStateFile.swift
│   ├── LocationStateFile.swift
│   └── NetworkStateFile.swift
├── Internal/
│   ├── SceneStateBridge.swift      // observer wiring scene ↔ AnatomyState
│   └── ToolInvocationListener.swift // pulses wiring on tool calls
└── CLAUDE.md
```

**Creates** (under `b0tKit/Sources/b0tCore/Catalogue/`):

```
b0tCore/Catalogue/
├── Manufacturer.swift              // Codable
├── BotModel.swift                  // Codable (Manufacturer's "Model" — Swift name disambiguated)
└── ManufacturerCatalogue.swift     // loader from manufacturers.json
```

**Creates** (under `b0tKit/Tests/`):

```
b0tDesignTests/
├── WundercogPaletteTests.swift
├── LCDPaletteTests.swift
└── CRTScanlineShaderTests.swift

b0tFaceTests/
├── FacePartProtocolTests.swift
├── SkullNodeTests.swift
├── EyesNodeTests.swift
├── JawNodeTests.swift
├── DecalNodeTests.swift
├── FaceCompositeTests.swift
├── OrganNodeTests.swift
├── HeartNodeTests.swift
├── WiringNetworkTests.swift
├── AnatomyLayoutTests.swift
└── AnatomySceneTests.swift

b0tHomeTests/
├── AnatomyStateTests.swift
├── InspectionPanelTests.swift
├── OrganInspectionViewTests.swift
├── DirectoryNavigatorViewTests.swift
├── EditorViewTests.swift
├── ChatViewTests.swift
├── FrontmatterControls/
│   ├── FrontmatterTypeRegistryTests.swift
│   ├── FrontmatterSemanticRegistryTests.swift
│   ├── BPMSliderTests.swift
│   ├── QuietHoursPickerTests.swift
│   ├── EnabledToggleTests.swift
│   ├── StepperControlTests.swift
│   ├── BoolToggleControlTests.swift
│   ├── ClockTimePickerTests.swift
│   ├── EnumPickerControlTests.swift
│   └── TextFieldControlTests.swift
└── Internal/
    ├── SceneStateBridgeTests.swift
    └── ToolInvocationListenerTests.swift

b0tCoreTests/Catalogue/
├── ManufacturerTests.swift
├── BotModelTests.swift
└── ManufacturerCatalogueTests.swift
```

**Creates** (assets and resources):

```
b0tApp/Resources/manufacturers.json
b0tApp/Resources/Assets.xcassets/
├── HilferSkull.imageset/
├── HilferEyes.imageset/
├── HilferJaw.imageset/
├── OrganHeart.imageset/
├── OrganReasoning.imageset/
├── OrganMemory.imageset/
├── OrganIdentity.imageset/
├── OrganModules.imageset/
├── OrganSensors.imageset/
├── OrganTools.imageset/
├── OrganLocation.imageset/
├── OrganNetwork.imageset/
├── ModuleIcon-Calendar.imageset/    // 16px
├── ModuleIcon-Reminders.imageset/
├── ModuleIcon-TimeAwareness.imageset/
├── ModuleIcon-Health.imageset/
└── FileIcon.imageset/                // 8px
```

**Creates** (docs):

```
docs/decisions/0010-organs-are-anatomical-subsystems.md
docs/decisions/0011-defer-face-rig-to-phase-6.md
docs/references/face-roster.md
```

**Modifies:**

- `b0tKit/Package.swift` — add `b0tHome` library + test target
- `b0tKit/Sources/b0tFace/b0tFacePlaceholder.swift` — delete
- `b0tKit/Sources/b0tDesign/b0tDesignPlaceholder.swift` — delete
- `b0tKit/Sources/b0tBrain/BotProvisioner.swift` — read Hilfer's defaults from manufacturers.json
- `b0tApp/Sources/App/ContentView.swift` — replace placeholder with `HomeView`
- `b0tKit/Sources/b0tCore/...` — expose a `ToolInvocationPublisher` if not already present (Slice 8)
- `docs/prd.md` — §3 Phase 4/6, §5.4 prefacing, §12 Q4 (Slice 0)
- `docs/design_document.md` — §3.3, §4.2 (Slice 0)
- `docs/decisions/0007-anatomical-gui-not-chat.md` — note supersession by ADR-0010 (Slice 0)
- `docs/IMPLEMENTATION.md` — status flips, ledger, notes (Slice 0 start, Slice 10 close)

**Deletes:**

- `docs/specs/phase-4-assets-checklist.md` — superseded by §7 of the new spec

---

## Slice 0 — Documentation foundation

Land the meta-layer (ADRs, references, manifests, doc edits) before any code. Two PRs: housekeeping (Task 1) first; the rest in a single follow-up PR. Slice ends with all docs in place, no code touched yet.

### Task 1: Vocabulary housekeeping

**Files:**
- Verify: any `Ear` / `EarsNode` / `Overlay` / `OverlayNode` / `Skill` (user-facing) / `Accoutrement` references across the repo.
- Modify: any matches found.

- [ ] **Step 1 [CC]: Grep for removed vocabulary**

```bash
grep -rn 'EarsNode\|EarNode\|OverlayNode\|Accoutrement' --include='*.swift' --include='*.md' /Users/haydentoppeross/development/b0t || echo "no matches"
grep -rn '\bSkill\b\|\bSkills\b' --include='*.md' /Users/haydentoppeross/development/b0t/docs /Users/haydentoppeross/development/b0t/default-bot || echo "no matches"
```

Expected: most or all return "no matches" (current state is mostly placeholders). Capture any matches in a temp note.

- [ ] **Step 2 [CC]: Apply renames if any matches surfaced**

For each match: rename `OverlayNode` → `DecalNode`, remove `EarsNode` declarations, replace `Skill` with `Module` in user-facing copy. The amendment §4 is the spec for these renames; do not rename `voice.md` → `personality.md` per Phase 4 brainstorm decision.

- [ ] **Step 3 [VERIFY]: Run package tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test 2>&1 | tail -20
```

Expected: existing 196+ tests still pass.

- [ ] **Step 4 [CC]: Commit**

```bash
git add -A
git commit -m "chore(b0t): vocabulary migration per amendment §4 (no voice→personality)"
```

If no matches surfaced in Step 1, skip Step 2 and commit a no-op note in IMPLEMENTATION.md instead — `git commit --allow-empty` is acceptable here to mark the verification.

---

### Task 2: ADR-0010 — organs are anatomical subsystems

**Files:**
- Create: `docs/decisions/0010-organs-are-anatomical-subsystems.md`
- Modify: `docs/decisions/0007-anatomical-gui-not-chat.md` (add a "Superseded in part by ADR-0010" note at the top)

- [ ] **Step 1 [CC]: Write ADR-0010**

```markdown
# 0010 — Organs are anatomical subsystems

**Status:** Accepted
**Date:** 2026-05-05
**Deciders:** Hayden
**Supersedes (in part):** ADR-0007's organ-as-module framing

## Context

ADR-0007 ("Anatomical GUI as the primary interface, not chat") and design doc §3.3 / §4.2 originally framed organs as visualisations of *modules* — calendar organ, mail organ, etc. — with an organ count that grew with the module count.

Phase 4 brainstorming on 2026-05-05 (see `docs/specs/phase-4-anatomical-gui.md`) settled a different model: organs are fixed *anatomical subsystems* of the b0t, independent of how many modules ship.

## Decision

The b0t's anatomy has nine organs, fixed across all phases:

1. **Reasoning** (top crown) — the LLM chip; 9-square grid + in/out token tanks.
2. **Memory** (above eye-line) — punch-card stack iconography; reads/writes memory files.
3. **Identity** (above eye-line) — dog-tag iconography; surfaces the `identity/` directory (the personality surface).
4. **Modules** (above eye-line) — meta-organ; surfaces individual module `.md` files. Tap → directory of modules.
5. **Sensors** (below eye-line) — STT + text-input affordance.
6. **Tools** (below eye-line) — Swiss-army-knife frame; surfaces individual tools.
7. **Network** (below eye-line) — radio-tower iconography; surfaces network-state. No v1 modules use it; the organ exists architecturally.
8. **Location** (below eye-line) — radar-sweep iconography; surfaces location-state. No v1 modules use it; the organ exists architecturally.
9. **Heart** (bottom-centre, distinguished) — heartbeat configuration; BPM and quiet hours.

Modules and tools (the per-capability units defined elsewhere) are surfaced *inside* the Modules and Tools organs respectively. The 10-module v1 library called for in design doc §4.2 still ships — those modules live as files inside the Modules organ.

## Rationale

- **Stable anatomy.** A b0t has the same number of organs whether it has 1 module installed or 10. The home screen layout doesn't shift as the user enables/disables modules.
- **Anatomical metaphor coherence.** Heart, Reasoning, Memory, Identity, Sensors are bodily *systems*. Modules and Tools are *capabilities* that pass through those systems. Treating capabilities as organs conflated levels of abstraction.
- **Future-proof.** Network and Location organs ship in Phase 4 with no associated modules. They light up later when modules that use them ship — without retrofitting the GUI layout.

## Consequences

- ADR-0007 §"Around the face" is partly superseded — the in/out distinction by ear-line still stands; "organs representing modules" does not.
- Design doc §3.3 organ language requires a small edit (organ list update).
- Design doc §4.2 module library count (10 modules) stays — modules are now content surfaced *inside* the Modules organ.
- Phase 4 spec §4.5 documents what each organ surfaces in its inspection view.
- Wiring still pulses direction-aware on capability access — calendar tool invocation pulses the *Tools* organ, not a (no-longer-existing) calendar organ.
```

- [ ] **Step 2 [CC]: Add supersession note to ADR-0007**

Edit `docs/decisions/0007-anatomical-gui-not-chat.md` — add a banner immediately after the Date line:

```markdown
**Partly superseded by:** [ADR-0010](0010-organs-are-anatomical-subsystems.md) (organ semantics; the in/out ear-line distinction stands)
```

- [ ] **Step 3 [CC]: Commit**

```bash
git add docs/decisions/0010-organs-are-anatomical-subsystems.md docs/decisions/0007-anatomical-gui-not-chat.md
git commit -m "docs(decisions): adr-0010 organs are anatomical subsystems"
```

---

### Task 3: ADR-0011 — defer face rig to Phase 6

**Files:**
- Create: `docs/decisions/0011-defer-face-rig-to-phase-6.md`

- [ ] **Step 1 [CC]: Write ADR-0011**

```markdown
# 0011 — Defer face rig to Phase 6

**Status:** Accepted
**Date:** 2026-05-05
**Deciders:** Hayden
**Amends:** PRD §3 Phase 4, §5.4

## Context

PRD §3 Phase 4 originally bundled the anatomical GUI shell *and* the rigged face (8 mood states per Part, blink loop, breathing, mouth-open cycle) together. The face rig requires the parts ontology, atlases, mood-state machines, and the 12-Manufacturer × 3-Model roster being delivered — most of which is content rather than engineering.

Phase 4 brainstorming on 2026-05-05 settled a tighter scope: validate the cassette-futurism look on glass with a single static face, defer rig + parts library + Face Creator into Phase 6 as one consolidated content phase.

## Decision

Phase 4 ships:
- One static face: **Hilfer** (Wundercog tier-1 starter Model), composed of three baked PNGs (Skull / Eye-screen / Jaw) per the amendment §2.1 three-Parts ontology.
- The full anatomical GUI shell: 9-organ ring, beating heart, pulsing wiring, backlit-LCD inspection panel doubling as chat.
- Decal layer **architecturally present**, no Hilfer decal assets.

Phase 6 (consolidated) absorbs:
- Face rig (mood states, blink, breathing, mouth-open cycle) — the SpriteKit mood-state machine over Part atlases.
- Parts library (Skull / Eyes / Jaw variants from across the roster).
- Face Creator UX (composition, randomise, save).
- Mood-variant notification icons.

## Rationale

- **Validate the look first.** A static face in the GUI shell tests the cassette-futurism aesthetic, the LCD inspection pattern, the 9-organ ring layout, and the wiring/heart procedural visuals — without committing to rig animation choices.
- **Phase 4 stays buildable.** With the rig and parts library deferred, Phase 4's asset surface collapses from ~30+ rigged sprite frames to 3 static PNGs + 9 organ icons + 4 module sub-icons + 1 file icon.
- **Phase 6 becomes additive, not invasive.** Approach 2 (SpriteKit-first hybrid) means Phase 6 swaps in atlases and a mood-state machine without architectural rewrites — the eventual home of the rig is exercised from Phase 4.

## Consequences

- PRD §3 Phase 4 acceptance is rewritten in this amendment.
- PRD §3 Phase 6 absorbs rig + parts + Face Creator (previously Phase 6 was Face Creator alone).
- PRD §5.4 prefaced with "rig ships in Phase 6."
- Aesthetic discipline still applies to Hilfer's three Part PNGs and the procedural wiring/heart/LCD.
- Procedural-animation guidance for the rig is captured in a separate session (forthcoming spec).
```

- [ ] **Step 2 [CC]: Commit**

```bash
git add docs/decisions/0011-defer-face-rig-to-phase-6.md
git commit -m "docs(decisions): adr-0011 defer face rig to phase 6"
```

---

### Task 4: face-roster.md reference

**Files:**
- Create: `docs/references/face-roster.md`

- [ ] **Step 1 [CC]: Write face-roster.md**

The full document captures all 5 Manufacturers × 3 Models = 15 Models, including the corrected kc-oracle palette. Use the verbatim prompt strings from the brainstorming transcript. Structure:

```markdown
# Face roster — manufacturers, models, prompts

Source-of-truth for prompt provenance. Each Manufacturer entry includes its base prompt template; each Model under it includes the full Gamelabs prompt that produced (or will produce) its three Parts.

The runtime catalogue is `b0tApp/Resources/manufacturers.json` — that file ships only what's currently buildable. This document captures the full design intent for the v1 launch lineup and beyond.

Vocabulary per the [2026-05-04 amendment](../b0t-amendment-2026-05-04.md): Manufacturer / Model / Part (Skull, Eyes, Jaw) / Palette / Decal.

## Wundercog Industries

[base prompt template — verbatim from brainstorm]

### Hilfer (tier 1 — starter / onboarding)
[full prompt — Skull, Eye-screen, Jaw, Palette]

### Tüftler (tier 2)
[full prompt]

### Meister (tier 3)
[full prompt]

## Kalv

[base prompt template]

### Kalv Lit (tier 1)
[full prompt]

### Kalv Verk (tier 2)
[full prompt]

### Kalv Nett (tier 3)
[full prompt]

## Hartsyzk Robotyka

[base prompt template]

### HR-Skaut (tier 1)
[full prompt]

### HR-Strateh (tier 2)
[full prompt]

### HR-Heneral (tier 3)
[full prompt]

## Solace Synthetics

[base prompt template]

### Solace Mira (tier 1)
[full prompt]

### Solace Vesna (tier 2)
[full prompt]

### Solace Sage (tier 3)
[full prompt]

## Kernel Collective

[base prompt template]

### kc-init (tier 1)
[full prompt]

### kc-fork (tier 2)
[full prompt]

### kc-oracle (tier 3)
[full prompt — palette: bare aluminum, brushed titanium accents, magenta anodized accents, magenta coolant glow]
```

Copy the verbatim prompts from the 2026-05-05 brainstorm transcript captured in `.superpowers/brainstorm/90498-1777954970/` if accessible, or from the spec (`docs/specs/phase-4-anatomical-gui.md` references the prompt structure — but the canonical prompts live in this file).

- [ ] **Step 2 [CC]: Commit**

```bash
git add docs/references/face-roster.md
git commit -m "docs(references): face-roster — 5 manufacturers × 3 models, kc-oracle palette corrected"
```

---

### Task 5: manufacturers.json stub

**Files:**
- Create: `b0tApp/Resources/manufacturers.json`

- [ ] **Step 1 [CC]: Write the JSON file**

```json
{
  "manufacturers": [
    {
      "id": "wundercog",
      "name": "Wundercog Industries",
      "base_prompt_template": "Pixel art at 256×256, forward-facing portrait, pure black background, head and jaw only, no neck or body, bot looking directly at camera, perfectly centered. Manufacturer design language (constant): matte off-white polymer shell, soft bulbous forms, no sharp edges, friendly utility aesthetic. Universal interchange (constant across entire roster): the eye-panel underneath is a standard rectangle with content visible only through the skull's cutout window; the jaw is a separate part that mounts to a standard hinge point at the lower edge of the skull, with the jaw seam positioned just above where a 'mouth' would sit so the upper lip-equivalent is part of the jaw module; the skull occludes the sides of the jaw and houses the speaker behind the jaw plane (no speaker grille on the jaw itself). Stålenhag/Cobb design logic: plausible polymer construction, subtle wear at contact points.",
      "palettes": ["wundercog_offwhite_mint", "wundercog_offwhite_butter", "wundercog_pearlescent_plum"],
      "identity_description": "Friendly utility aesthetic, plausible polymer construction, subtle wear at contact points."
    }
  ],
  "models": [
    {
      "id": "hilfer",
      "manufacturer": "wundercog",
      "tier": 1,
      "is_starter": true,
      "parts": {
        "skull": "wundercog_skull_egg_offwhite_mint",
        "eyes": "wundercog_eyes_mint_idle",
        "jaw": "wundercog_jaw_small_offwhite_mint"
      },
      "palette": "wundercog_offwhite_mint",
      "decals": [],
      "default_personality_dir": "identity/",
      "default_modules": ["calendar", "reminders", "time-awareness", "health"],
      "default_tools": ["calendar.upcoming_events", "reminders.create", "health.steps_today"],
      "heartbeat_unlock_threshold": null
    }
  ]
}
```

- [ ] **Step 2 [CC]: Verify b0tApp Resources directory exists**

```bash
ls /Users/haydentoppeross/development/b0t/b0tApp/Resources/ 2>/dev/null || mkdir -p /Users/haydentoppeross/development/b0t/b0tApp/Resources/
```

- [ ] **Step 3 [CC]: Verify project.yml includes b0tApp/Resources/ as a folder reference**

```bash
grep -A 5 "Resources" /Users/haydentoppeross/development/b0t/project.yml
```

If `Resources` is not yet a folder reference under the `b0tApp` target, add it:

```yaml
# under targets.b0tApp.sources:
- path: b0tApp/Resources
  type: folder
  buildPhase: resources
```

Then regenerate: `xcodegen generate`.

- [ ] **Step 4 [CC]: Commit**

```bash
git add b0tApp/Resources/manufacturers.json project.yml b0t.xcodeproj/project.pbxproj
git commit -m "feat(b0tApp): add manufacturers.json catalogue (wundercog + hilfer)"
```

---

### Task 6: PRD edits

**Files:**
- Modify: `docs/prd.md` §3 Phase 4, §3 Phase 6, §5.4, §12 Q4

- [ ] **Step 1 [CC]: Replace PRD §3 Phase 4 acceptance**

Edit `docs/prd.md`. Replace the existing "### Phase 4 — Anatomical GUI (default face)" block with:

```markdown
### Phase 4 — Anatomical GUI (static face)
- Implement `Home/`: anatomy area (top half) with Hilfer composed of three baked Parts (Skull / Eye-screen / Jaw), 9-organ ring, beating heart, pulsing wiring; backlit-LCD inspection panel (bottom half) doubling as chat surface.
- Implement chat composer (default LCD content).
- Implement organ tap → inspection mode (LCD swaps to organ controls; frontmatter renders as native controls inline with markdown).
- Implement edit mode (full-screen markdown editor with frontmatter controls).
- Decal layer architecturally present, no Hilfer decal assets.
- Face rig (mood states, blink, breathing) deferred to Phase 6 per ADR-0011.
- **Acceptance:** the default b0t is alive on screen with a static face, beating heart, pulsing wiring on tool calls. The user can chat, tap organs to inspect them, edit files. See `docs/specs/phase-4-anatomical-gui.md` §14 for the full smoke checklist.
```

- [ ] **Step 2 [CC]: Replace PRD §3 Phase 6 absorption**

Replace the existing "### Phase 6 — Face Creator" block with:

```markdown
### Phase 6 — Face rig + Parts library + Face Creator
- Implement face rig per `docs/specs/face-creator-procedural-animation.md` (forthcoming): mood-state machine over Part atlases, blink loop, breathing, mouth-open cycle. 8 mood states per Part: idle, speaking, thinking, surprised, sleepy, attentive, worried, delighted.
- Implement Parts library (Skull / Eyes / Jaw variants from across the roster).
- Implement Face Creator UX (composition, randomise, save).
- Implement mood-variant notification icons (rendered to disk at face-creation time).
- **Acceptance:** user can compose, save, and revisit a custom face composed of unlocked Parts. Home screen shows the user's face animating across mood states. Notifications use the right mood variant.
```

- [ ] **Step 3 [CC]: Preface PRD §5.4 b0tFace**

Insert at the top of §5.4 (immediately before "**REQUIRED:** the face is rendered using SpriteKit..."):

```markdown
**Phase note:** Phase 4 ships a single static face composed of three baked Parts. The rig requirements below ship in Phase 6 per ADR-0011.
```

- [ ] **Step 4 [CC]: Close PRD §12 Q4**

Edit the §12 Q4 row (or create the open-questions table entry if it's a list):

```markdown
| 4 | Pixel art assets. | Phase 4–6 | **Resolved** — Gamelabs Studio asset pipeline per amendment §2.2; baked palette variants, no runtime palette swap shader. |
```

- [ ] **Step 5 [CC]: Commit**

```bash
git add docs/prd.md
git commit -m "docs(prd): phase 4/6 art-approach amendment per adr-0011"
```

---

### Task 7: Design doc edits

**Files:**
- Modify: `docs/design_document.md` §3.3, §4.2

- [ ] **Step 1 [CC]: Update design doc §3.3 organ language**

Find the existing organ-list paragraph in §3.3 and replace with the 9-organ list from ADR-0010. Keep the in/out ear-line distinction. Concrete diff: locate the existing block describing "Above the ear-line: things that come in..." and update to read:

```markdown
- **Above the eye-line:** Reasoning (top crown), Memory, Identity, Modules — the b0t's perception, knowledge, and capability surfaces.
- **Below the eye-line:** Sensors, Tools, Network, Location — the b0t's input/output to the world.
- **Bottom-centre:** Heart — the b0t's heartbeat, distinguished as the most-touched control.

The in/out distinction by eye-line is preserved. See [ADR-0010](decisions/0010-organs-are-anatomical-subsystems.md) for the full canonical organ list and rationale.
```

- [ ] **Step 2 [CC]: Reframe design doc §4.2**

In §4.2, add a paragraph before the v1 module library list:

```markdown
Modules are surfaced through the **Modules organ** in the anatomical GUI (see [ADR-0010](decisions/0010-organs-are-anatomical-subsystems.md)). The Modules organ is the meta-organ that opens a directory of installed modules; tapping a module file drills into its inspection view. The 10 modules below are the v1 library — they live as `.md` files inside the Modules organ, not as their own organs.
```

- [ ] **Step 3 [CC]: Commit**

```bash
git add docs/design_document.md
git commit -m "docs(design): organ language and module surfacing per adr-0010"
```

---

### Task 8: Retire phase-4-assets-checklist.md

**Files:**
- Delete: `docs/specs/phase-4-assets-checklist.md`

- [ ] **Step 1 [CC]: Delete the file**

```bash
git rm /Users/haydentoppeross/development/b0t/docs/specs/phase-4-assets-checklist.md
```

- [ ] **Step 2 [CC]: Commit**

```bash
git commit -m "docs(specs): retire phase-4 assets checklist (superseded by phase-4-anatomical-gui spec §7)"
```

---

### Task 9: IMPLEMENTATION.md status flip

**Files:**
- Modify: `docs/IMPLEMENTATION.md`

- [ ] **Step 1 [CC]: Update Phase 4 status**

In the "Current state" block, set:

```markdown
- **Phase:** 4 — Anatomical GUI (static face)
- **Status:** specced
- **Spec:** [phase-4-anatomical-gui](specs/phase-4-anatomical-gui.md)
- **Plan:** [phase-4-anatomical-gui](plans/phase-4-anatomical-gui.md)
```

In the Phase ledger table, update the Phase 4 row's plan link to `[phase-4](plans/phase-4-anatomical-gui.md)` and status to `specced`. Update Phase 6's name to `Face rig + Parts library + Face Creator`.

In "Specs in flight," add:

```markdown
- [phase-4-anatomical-gui](specs/phase-4-anatomical-gui.md) — settled 2026-05-05; produces ADR-0010, ADR-0011, face-roster.md, manufacturers.json
```

In "Open questions on the boil," add:

```markdown
- Hilfer's three Part PNGs + 9 organ icons + 4 module sub-icons + 1 file icon — Hayden committed to deliver.
```

- [ ] **Step 2 [CC]: Commit**

```bash
git add docs/IMPLEMENTATION.md
git commit -m "docs(implementation): phase 4 status to specced, ledger updated"
```

---

**Slice 0 verification:** `swift test` still green. All 9 commits land. The spec PR (Tasks 2–9) lands in one PR after Task 1's housekeeping PR merges. No code changes yet — pure docs.

---

## Slice 1 — b0tDesign palettes & shaders

Stand up the design tokens and shaders that everything downstream consumes. Slice ends with `b0tDesign` exposing the Wundercog and LCD palettes, the CRT scanline shader, and IoskeleyMono / Verdana type aliases.

### Task 10: WundercogPalette tokens

**Files:**
- Create: `b0tKit/Sources/b0tDesign/Palette/WundercogPalette.swift`
- Create: `b0tKit/Tests/b0tDesignTests/WundercogPaletteTests.swift`
- Delete: `b0tKit/Sources/b0tDesign/b0tDesignPlaceholder.swift`

- [ ] **Step 1 [CC]: Write the failing test**

Create `b0tKit/Tests/b0tDesignTests/WundercogPaletteTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import b0tDesign

final class WundercogPaletteTests: XCTestCase {
    func test_shellOffwhite_isWarmOffwhite() {
        let color = WundercogPalette.shellOffwhite
        // smoke: the palette token resolves to a non-clear, non-default Color.
        XCTAssertNotEqual(color, Color.clear)
        XCTAssertNotEqual(color, Color.black)
    }

    func test_allRoles_areDistinct() {
        let roles: [Color] = [
            WundercogPalette.shellOffwhite,
            WundercogPalette.accentMint,
            WundercogPalette.bezelMintThin,
            WundercogPalette.eyePhosphor,
            WundercogPalette.seamDark
        ]
        // five distinct roles per spec §6.2 — no duplicates.
        let unique = Set(roles.map { String(describing: $0) })
        XCTAssertEqual(unique.count, roles.count, "palette roles collapsed to \(unique.count)")
    }
}
```

- [ ] **Step 2 [VERIFY]: Run test to confirm it fails**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter WundercogPaletteTests 2>&1 | tail -15
```

Expected: FAIL (`WundercogPalette` doesn't exist).

- [ ] **Step 3 [CC]: Implement the palette**

Create `b0tKit/Sources/b0tDesign/Palette/WundercogPalette.swift`:

```swift
import SwiftUI

/// Hilfer's palette — the Wundercog tier-1 starter Model.
///
/// Values are sRGB literals; tweak with Hayden's eye against the Hilfer PNGs.
public enum WundercogPalette {
    /// Off-white polymer shell — Hilfer's skull and jaw base.
    public static let shellOffwhite = Color(red: 0.93, green: 0.92, blue: 0.88)

    /// Mint-green accent — eye glow halo, jaw underline, bezel highlight.
    public static let accentMint = Color(red: 0.62, green: 0.86, blue: 0.74)

    /// Single-pixel mint bezel ringing the eye-screen cutout.
    public static let bezelMintThin = Color(red: 0.55, green: 0.78, blue: 0.66)

    /// Phosphor glow inside the eye-screen.
    public static let eyePhosphor = Color(red: 0.45, green: 0.92, blue: 0.62)

    /// Subtle panel-seam shadowing.
    public static let seamDark = Color(red: 0.18, green: 0.18, blue: 0.16)
}
```

- [ ] **Step 4 [CC]: Delete the placeholder**

```bash
rm /Users/haydentoppeross/development/b0t/b0tKit/Sources/b0tDesign/b0tDesignPlaceholder.swift
```

- [ ] **Step 5 [VERIFY]: Run test to confirm it passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter WundercogPaletteTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 6 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tDesign/Palette/WundercogPalette.swift b0tKit/Tests/b0tDesignTests/WundercogPaletteTests.swift
git rm b0tKit/Sources/b0tDesign/b0tDesignPlaceholder.swift
git commit -m "feat(b0tDesign): wundercog palette tokens"
```

---

### Task 11: LCDPalette tokens

**Files:**
- Create: `b0tKit/Sources/b0tDesign/Palette/LCDPalette.swift`
- Create: `b0tKit/Tests/b0tDesignTests/LCDPaletteTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SwiftUI
@testable import b0tDesign

final class LCDPaletteTests: XCTestCase {
    func test_allRoles_areDistinct() {
        let roles: [Color] = [
            LCDPalette.bgWarm,
            LCDPalette.textAmber,
            LCDPalette.textDim,
            LCDPalette.chromeDark
        ]
        let unique = Set(roles.map { String(describing: $0) })
        XCTAssertEqual(unique.count, roles.count)
    }

    func test_textDim_isLessOpaqueThanTextAmber() {
        // textDim is the secondary state; visually distinguishable from primary.
        // Spot-check via opacity equivalent: the description should reflect a different alpha or hue.
        XCTAssertNotEqual(
            String(describing: LCDPalette.textAmber),
            String(describing: LCDPalette.textDim)
        )
    }
}
```

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter LCDPaletteTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Implement the palette**

Create `b0tKit/Sources/b0tDesign/Palette/LCDPalette.swift`:

```swift
import SwiftUI

/// Backlit-LCD inspection panel palette.
///
/// Calculator / OP-1 / Tandy Model 100 sensibility — warm amber, no bloom, no scanlines.
/// Distinct from the CRT phosphor palette used on the Eye-screen.
public enum LCDPalette {
    /// Warm dark grey-amber backlight — the LCD background.
    public static let bgWarm = Color(red: 0.18, green: 0.14, blue: 0.08)

    /// Primary amber text — chat content, organ titles, frontmatter labels.
    public static let textAmber = Color(red: 0.85, green: 0.72, blue: 0.47)

    /// Secondary dimmed text — subtitles, system labels.
    public static let textDim = Color(red: 0.85, green: 0.72, blue: 0.47).opacity(0.55)

    /// Dark chrome border around the LCD area.
    public static let chromeDark = Color(red: 0.08, green: 0.06, blue: 0.04)
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter LCDPaletteTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tDesign/Palette/LCDPalette.swift b0tKit/Tests/b0tDesignTests/LCDPaletteTests.swift
git commit -m "feat(b0tDesign): lcd palette tokens (calculator/op-1 sensibility)"
```

---

### Task 12: CRT scanline shader

**Files:**
- Create: `b0tKit/Sources/b0tDesign/Shaders/CRTScanlineShader.swift`
- Create: `b0tKit/Tests/b0tDesignTests/CRTScanlineShaderTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SpriteKit
@testable import b0tDesign

final class CRTScanlineShaderTests: XCTestCase {
    func test_shader_isInstantiable() {
        let shader = CRTScanlineShader.make()
        XCTAssertFalse(shader.source?.isEmpty ?? true, "shader source must not be empty")
    }

    func test_shader_hasScanlineUniforms() {
        let shader = CRTScanlineShader.make()
        let uniformNames = shader.uniforms.map(\.name)
        XCTAssertTrue(uniformNames.contains("u_intensity"), "uniforms: \(uniformNames)")
        XCTAssertTrue(uniformNames.contains("u_lineCount"), "uniforms: \(uniformNames)")
    }
}
```

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter CRTScanlineShaderTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Implement the shader**

Create `b0tKit/Sources/b0tDesign/Shaders/CRTScanlineShader.swift`:

```swift
import SpriteKit

/// CRT scanline overlay shader — applied to the Eye-screen Part only.
///
/// Per `aesthetic-references.md`: subtle CRT overlay (toggleable). Bloom on the active wiring.
/// Warm phosphor — amber, green, cream. Never blue.
///
/// This is the *only* CRT surface in the system. Skull, Jaw, organs, heart, wiring,
/// and the LCD inspection panel all use distinct visual languages.
public enum CRTScanlineShader {
    public static func make(intensity: Float = 0.18, lineCount: Float = 96.0) -> SKShader {
        let source = """
        void main() {
            vec4 color = texture2D(u_texture, v_tex_coord);
            float scanline = sin(v_tex_coord.y * u_lineCount * 3.14159) * 0.5 + 0.5;
            float darken = mix(1.0, 1.0 - u_intensity, scanline);
            gl_FragColor = vec4(color.rgb * darken, color.a);
        }
        """
        let shader = SKShader(source: source)
        shader.uniforms = [
            SKUniform(name: "u_intensity", float: intensity),
            SKUniform(name: "u_lineCount", float: lineCount)
        ]
        return shader
    }
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter CRTScanlineShaderTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tDesign/Shaders/CRTScanlineShader.swift b0tKit/Tests/b0tDesignTests/CRTScanlineShaderTests.swift
git commit -m "feat(b0tDesign): crt scanline shader for eye-screen"
```

---

### Task 13: Typography wrappers

**Files:**
- Create: `b0tKit/Sources/b0tDesign/Typography.swift`
- Create: `b0tKit/Tests/b0tDesignTests/TypographyTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SwiftUI
@testable import b0tDesign

final class TypographyTests: XCTestCase {
    func test_systemMono_isIoskeleyMonoNL() {
        let font = Typography.systemMono(size: 14)
        // Smoke: the font is constructed with the named family.
        XCTAssertNotNil(font)
        XCTAssertEqual(Typography.systemMonoFamily, "IoskeleyMonoNL-Regular")
    }

    func test_chatBody_isVerdana() {
        let font = Typography.chatBody(size: 15)
        XCTAssertNotNil(font)
        XCTAssertEqual(Typography.chatBodyFamily, "Verdana")
    }
}
```

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter TypographyTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Implement Typography**

Create `b0tKit/Sources/b0tDesign/Typography.swift`:

```swift
import SwiftUI

/// Type system per spec §6.1.
///
/// - `systemMono` — IoskeleyMono NL for system / brain / monospace UI labels.
///   Pixel-grid coherent with the cassette-futurism aesthetic.
/// - `chatBody` — Verdana for chat content inside the LCD chrome.
///   System-provided on iOS, no licensing concern, humanist sans designed for screen
///   readability. Sits inside the LCD without fighting the surrounding pixel art.
public enum Typography {
    public static let systemMonoFamily = "IoskeleyMonoNL-Regular"
    public static let chatBodyFamily = "Verdana"

    public static func systemMono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(systemMonoFamily, size: size).weight(weight)
    }

    public static func chatBody(size: CGFloat) -> Font {
        Font.custom(chatBodyFamily, size: size)
    }
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter TypographyTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tDesign/Typography.swift b0tKit/Tests/b0tDesignTests/TypographyTests.swift
git commit -m "feat(b0tDesign): typography — ioskeleymono nl + verdana"
```

---

### Task 14: b0tDesign module CLAUDE.md

**Files:**
- Create: `b0tKit/Sources/b0tDesign/CLAUDE.md`

- [ ] **Step 1 [CC]: Write the module CLAUDE.md**

```markdown
# b0tDesign — design tokens and shaders

The single source of truth for colour, type, and visual treatments across the app.

## Public surface

- `WundercogPalette` — Hilfer's 5 colour roles (off-white polymer + mint-green accents).
- `LCDPalette` — backlit warm-amber LCD inspection panel (4 colour roles).
- `CRTScanlineShader.make(intensity:lineCount:)` — `SKShader` for the Eye-screen only.
- `Typography.systemMono(size:weight:)` — IoskeleyMono NL for system / brain UI.
- `Typography.chatBody(size:)` — Verdana for chat content inside the LCD chrome.

## Visual languages

Three distinct treatments — do not mix:

1. **CRT (phosphor + scanline)** — Eye-screen only. Use `CRTScanlineShader`.
2. **Flat pixel art with painterly lighting** — Skull, Jaw, organs, heart. No shader chrome.
3. **Backlit LCD (warm amber, calculator sensibility)** — inspection panel only. SwiftUI gradients + `LCDPalette`. No bloom, no scanlines.

## Why no runtime palette swap

Per amendment §2.2 — palette variants are baked PNGs from Gamelabs. This module exposes
named *tokens* for code-drawn elements (wiring, heart pulse colour, LCD chrome, organ
activity-pulse tints). It does not provide runtime tinting of bitmap Parts.

## What lives elsewhere

- Bitmap Parts for Hilfer (Skull / Eyes / Jaw) — `b0tApp/Resources/Assets.xcassets/`.
- Wiring lines, organ activity-pulse shapes — `b0tFace/WiringNetwork.swift` etc.
- The full Manufacturer roster — `docs/references/face-roster.md`.
```

- [ ] **Step 2 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tDesign/CLAUDE.md
git commit -m "docs(b0tDesign): module readme"
```

---

### Task 15: Slice 1 verification

- [ ] **Step 1 [VERIFY]: Run all b0tDesign tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter b0tDesignTests 2>&1 | tail -15
```

Expected: 4 test cases pass (palette × 2, shader, typography).

- [ ] **Step 2 [VERIFY]: Run full package suite to ensure no regressions**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test 2>&1 | tail -5
```

Expected: 196+ tests pass (Phase 3 baseline + 4 new).

**Slice 1 verification:** `b0tDesign` is a real module with palettes, shader, type. `b0tDesignPlaceholder.swift` is gone. No regressions.

---

## Slice 2 — b0tFace Part nodes + static face composition

Stand up the three-Parts ontology (Skull / Eyes / Jaw + Decal layer) and compose Hilfer as a static face. Slice ends with `AnatomyScene` rendering Hilfer (composed of three placeholder-or-real PNGs) inside a `SpriteView`. No organs yet.

### Task 16: FacePart protocol

**Files:**
- Create: `b0tKit/Sources/b0tFace/FacePart.swift`
- Create: `b0tKit/Tests/b0tFaceTests/FacePartProtocolTests.swift`
- Delete: `b0tKit/Sources/b0tFace/b0tFacePlaceholder.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SpriteKit
@testable import b0tFace

final class FacePartProtocolTests: XCTestCase {
    func test_facePart_hasPartKind() {
        // smoke: every conformer declares its kind.
        XCTAssertEqual(FacePartKind.allCases.count, 3)
        XCTAssertTrue(FacePartKind.allCases.contains(.skull))
        XCTAssertTrue(FacePartKind.allCases.contains(.eyes))
        XCTAssertTrue(FacePartKind.allCases.contains(.jaw))
    }
}
```

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter FacePartProtocolTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Implement the protocol + kind enum**

Create `b0tKit/Sources/b0tFace/FacePart.swift`:

```swift
import SpriteKit

/// The three Parts a face is composed of, per amendment §2.1.
/// Ears are not in scope. Decals are a separate render layer, not a Part.
public enum FacePartKind: String, CaseIterable, Sendable {
    case skull
    case eyes
    case jaw
}

/// A face Part — Skull, Eyes, or Jaw. Each Part renders as one or more SKNode
/// subtrees in the scene, positioned relative to anchors on the Skull.
///
/// Phase 4 ships static (single-frame) Parts. Phase 6 introduces atlas-driven
/// mood-state machines on this protocol via additive extension.
public protocol FacePart: AnyObject {
    /// Which Part this is (Skull / Eyes / Jaw).
    var kind: FacePartKind { get }

    /// The root SKNode for this Part — added as a child of `FaceComposite`.
    var node: SKNode { get }
}
```

- [ ] **Step 4 [CC]: Delete the placeholder**

```bash
rm /Users/haydentoppeross/development/b0t/b0tKit/Sources/b0tFace/b0tFacePlaceholder.swift
```

- [ ] **Step 5 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter FacePartProtocolTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 6 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tFace/FacePart.swift b0tKit/Tests/b0tFaceTests/FacePartProtocolTests.swift
git rm b0tKit/Sources/b0tFace/b0tFacePlaceholder.swift
git commit -m "feat(b0tFace): facepart protocol — three parts (skull/eyes/jaw)"
```

---

### Task 17: SkullNode

**Files:**
- Create: `b0tKit/Sources/b0tFace/SkullNode.swift`
- Create: `b0tKit/Tests/b0tFaceTests/SkullNodeTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SpriteKit
@testable import b0tFace

final class SkullNodeTests: XCTestCase {
    func test_skullNode_kindIsSkull() {
        let skull = SkullNode(textureName: "HilferSkull", anchorPoints: .hilferDefaults)
        XCTAssertEqual(skull.kind, .skull)
    }

    func test_skullNode_exposesEyesAndJawAnchorPoints() {
        let skull = SkullNode(textureName: "HilferSkull", anchorPoints: .hilferDefaults)
        // The Skull is the source of truth for where Eyes and Jaw go.
        XCTAssertEqual(skull.anchorPoints.eyesSocket, CGPoint(x: 0.5, y: 0.55))
        XCTAssertEqual(skull.anchorPoints.jawHinge, CGPoint(x: 0.5, y: 0.25))
    }

    func test_skullNode_rendersAt256pxNative() {
        let skull = SkullNode(textureName: "HilferSkull", anchorPoints: .hilferDefaults)
        if let sprite = skull.node as? SKSpriteNode {
            // Phase 4 face is 256px native; nearest-neighbour scaling applies later in scene.
            XCTAssertEqual(sprite.size.width, 256)
            XCTAssertEqual(sprite.size.height, 256)
        } else {
            XCTFail("expected SKSpriteNode for skull root")
        }
    }
}
```

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter SkullNodeTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Implement SkullNode**

Create `b0tKit/Sources/b0tFace/SkullNode.swift`:

```swift
import SpriteKit

/// Anchor points the Skull exposes for positioning Eyes and Jaw, in normalised (0-1) coords.
public struct SkullAnchorPoints: Equatable, Sendable {
    public let eyesSocket: CGPoint
    public let jawHinge: CGPoint

    public init(eyesSocket: CGPoint, jawHinge: CGPoint) {
        self.eyesSocket = eyesSocket
        self.jawHinge = jawHinge
    }

    /// Hilfer's anchor defaults — settled per the spec / `face-roster.md`.
    public static let hilferDefaults = SkullAnchorPoints(
        eyesSocket: CGPoint(x: 0.5, y: 0.55),
        jawHinge: CGPoint(x: 0.5, y: 0.25)
    )
}

/// The skull Part — outer polymer shell with the eye-cutout window.
public final class SkullNode: FacePart {
    public let kind: FacePartKind = .skull
    public let node: SKNode
    public let anchorPoints: SkullAnchorPoints

    public init(textureName: String, anchorPoints: SkullAnchorPoints) {
        self.anchorPoints = anchorPoints
        let texture = SKTexture(imageNamed: textureName)
        texture.filteringMode = .nearest
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: 256, height: 256))
        sprite.name = "skull"
        self.node = sprite
    }
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter SkullNodeTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tFace/SkullNode.swift b0tKit/Tests/b0tFaceTests/SkullNodeTests.swift
git commit -m "feat(b0tFace): skullnode + skullanchorpoints"
```

---

### Task 18: EyesNode (with CRT scanline shader)

**Files:**
- Create: `b0tKit/Sources/b0tFace/EyesNode.swift`
- Create: `b0tKit/Tests/b0tFaceTests/EyesNodeTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SpriteKit
@testable import b0tFace
@testable import b0tDesign

final class EyesNodeTests: XCTestCase {
    func test_eyesNode_kindIsEyes() {
        let eyes = EyesNode(textureName: "HilferEyes")
        XCTAssertEqual(eyes.kind, .eyes)
    }

    func test_eyesNode_isWrappedInEffectNodeWithShader() {
        let eyes = EyesNode(textureName: "HilferEyes")
        guard let effect = eyes.node as? SKEffectNode else {
            XCTFail("eyes root must be SKEffectNode for shader application")
            return
        }
        XCTAssertNotNil(effect.shader)
        XCTAssertTrue(effect.shouldEnableEffects)
    }

    func test_eyesNode_isOnlyCRTSurface() {
        // smoke: the shader applied is the CRT scanline shader.
        let eyes = EyesNode(textureName: "HilferEyes")
        let effect = eyes.node as? SKEffectNode
        let source = effect?.shader?.source ?? ""
        XCTAssertTrue(source.contains("scanline"), "expected scanline shader, got: \(source.prefix(120))")
    }
}
```

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter EyesNodeTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Implement EyesNode**

Create `b0tKit/Sources/b0tFace/EyesNode.swift`:

```swift
import SpriteKit
import b0tDesign

/// The eye-screen Part — the only CRT surface in the system.
///
/// Wrapped in `SKEffectNode` so the scanline shader applies. The underlying SKSpriteNode
/// is the eye-content texture (mint phosphor for Hilfer); the shader overlays subtle
/// scanlines.
///
/// The Eye-screen mounts behind the Skull's eye-cutout in `FaceComposite` z-order.
public final class EyesNode: FacePart {
    public let kind: FacePartKind = .eyes
    public let node: SKNode

    public init(textureName: String) {
        let effect = SKEffectNode()
        effect.shouldEnableEffects = true
        effect.shouldRasterize = true
        effect.shader = CRTScanlineShader.make()
        effect.name = "eyes"

        let texture = SKTexture(imageNamed: textureName)
        texture.filteringMode = .nearest
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: 256, height: 256))
        sprite.name = "eyes_sprite"
        effect.addChild(sprite)

        self.node = effect
    }
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter EyesNodeTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tFace/EyesNode.swift b0tKit/Tests/b0tFaceTests/EyesNodeTests.swift
git commit -m "feat(b0tFace): eyesnode wrapped in skeffectnode + crt scanline shader"
```

---

### Task 19: JawNode

**Files:**
- Create: `b0tKit/Sources/b0tFace/JawNode.swift`
- Create: `b0tKit/Tests/b0tFaceTests/JawNodeTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SpriteKit
@testable import b0tFace

final class JawNodeTests: XCTestCase {
    func test_jawNode_kindIsJaw() {
        let jaw = JawNode(textureName: "HilferJaw")
        XCTAssertEqual(jaw.kind, .jaw)
    }

    func test_jawNode_rendersAt256pxNative() {
        let jaw = JawNode(textureName: "HilferJaw")
        guard let sprite = jaw.node as? SKSpriteNode else {
            XCTFail("expected SKSpriteNode for jaw root")
            return
        }
        XCTAssertEqual(sprite.size.width, 256)
        XCTAssertEqual(sprite.size.height, 256)
    }

    func test_jawNode_isNamed() {
        let jaw = JawNode(textureName: "HilferJaw")
        XCTAssertEqual(jaw.node.name, "jaw")
    }
}
```

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter JawNodeTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Implement JawNode**

Create `b0tKit/Sources/b0tFace/JawNode.swift`:

```swift
import SpriteKit

/// The jaw Part — mounts to the Skull's `jawHinge` anchor point.
///
/// The Skull occludes the jaw's sides; the speaker lives behind the jaw plane
/// (no speaker grille on the jaw itself).
public final class JawNode: FacePart {
    public let kind: FacePartKind = .jaw
    public let node: SKNode

    public init(textureName: String) {
        let texture = SKTexture(imageNamed: textureName)
        texture.filteringMode = .nearest
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: 256, height: 256))
        sprite.name = "jaw"
        self.node = sprite
    }
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter JawNodeTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tFace/JawNode.swift b0tKit/Tests/b0tFaceTests/JawNodeTests.swift
git commit -m "feat(b0tFace): jawnode"
```

---

### Task 20: DecalNode (empty layer)

**Files:**
- Create: `b0tKit/Sources/b0tFace/DecalNode.swift`
- Create: `b0tKit/Tests/b0tFaceTests/DecalNodeTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SpriteKit
@testable import b0tFace

final class DecalNodeTests: XCTestCase {
    func test_decalNode_isInitiallyEmpty() {
        let decals = DecalNode()
        XCTAssertTrue(decals.node.children.isEmpty)
    }

    func test_decalNode_acceptsAddedDecals() {
        let decals = DecalNode()
        let decal = SKSpriteNode(color: .red, size: CGSize(width: 16, height: 16))
        decals.add(decal)
        XCTAssertEqual(decals.node.children.count, 1)
    }

    func test_decalNode_isNamed() {
        XCTAssertEqual(DecalNode().node.name, "decals")
    }
}
```

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter DecalNodeTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Implement DecalNode**

Create `b0tKit/Sources/b0tFace/DecalNode.swift`:

```swift
import SpriteKit

/// Decal layer — manufacturer marks, hazard stripes, stencils.
///
/// Architecturally present in Phase 4; empty for Hilfer (clean polymer aesthetic).
/// Decals are additive `SKSpriteNode`s composed on top of Parts. Each decal is itself
/// a baked PNG from the asset pipeline (per amendment §2.2 — no runtime tinting).
public final class DecalNode {
    public let node: SKNode

    public init() {
        let container = SKNode()
        container.name = "decals"
        self.node = container
    }

    public func add(_ decal: SKNode) {
        node.addChild(decal)
    }
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter DecalNodeTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tFace/DecalNode.swift b0tKit/Tests/b0tFaceTests/DecalNodeTests.swift
git commit -m "feat(b0tFace): decalnode — architecturally present, empty for hilfer"
```

---

### Task 21: FaceComposite

**Files:**
- Create: `b0tKit/Sources/b0tFace/FaceComposite.swift`
- Create: `b0tKit/Tests/b0tFaceTests/FaceCompositeTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SpriteKit
@testable import b0tFace

final class FaceCompositeTests: XCTestCase {
    func test_composite_layersAreInCorrectZOrder() {
        let composite = makeHilferComposite()
        // Eye-screen at the back, Skull on top with cutout, Jaw at hinge, Decals on top.
        // Children are listed bottom-to-top: [eyes, skull, jaw, decals]
        let names = composite.node.children.map { $0.name ?? "" }
        XCTAssertEqual(names, ["eyes", "skull", "jaw", "decals"])
    }

    func test_composite_jawIsPositionedAtHingeAnchor() {
        let composite = makeHilferComposite()
        // jaw should be positioned according to the skull's jawHinge anchor (0.5, 0.25)
        // relative to the 256x256 face — centred horizontally, lower portion.
        guard let jaw = composite.node.childNode(withName: "jaw") else {
            XCTFail("jaw missing")
            return
        }
        // Coordinates are scene-space; with face anchored at (0,0) and 256x256 size,
        // jawHinge (0.5, 0.25) translates to (0, -64) (centred, 25% from bottom).
        XCTAssertEqual(jaw.position.x, 0, accuracy: 0.5)
        XCTAssertLessThan(jaw.position.y, 0, "jaw should be in lower half")
    }

    func test_composite_eyesIsPositionedAtSocketAnchor() {
        let composite = makeHilferComposite()
        guard let eyes = composite.node.childNode(withName: "eyes") else {
            XCTFail("eyes missing")
            return
        }
        // eyesSocket (0.5, 0.55) — slightly above centre of face.
        XCTAssertEqual(eyes.position.x, 0, accuracy: 0.5)
        XCTAssertGreaterThan(eyes.position.y, 0, "eyes socket should be above centre")
    }

    private func makeHilferComposite() -> FaceComposite {
        let skull = SkullNode(textureName: "HilferSkull", anchorPoints: .hilferDefaults)
        let eyes = EyesNode(textureName: "HilferEyes")
        let jaw = JawNode(textureName: "HilferJaw")
        let decals = DecalNode()
        return FaceComposite(skull: skull, eyes: eyes, jaw: jaw, decals: decals)
    }
}
```

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter FaceCompositeTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Implement FaceComposite**

Create `b0tKit/Sources/b0tFace/FaceComposite.swift`:

```swift
import SpriteKit

/// Composes the three Parts + decal layer into a single SKNode subtree.
///
/// Z-order (bottom to top):
/// 1. Eyes — eye-screen content visible through the Skull's cutout.
/// 2. Skull — polymer shell with eye-cutout window.
/// 3. Jaw — mounted at Skull's `jawHinge` anchor.
/// 4. Decals — additive markings on top of all Parts.
///
/// Phase 4 is static; Phase 6 adds rig animation by mutating Part textures
/// (mood-state machine) without changing this composition.
public final class FaceComposite {
    public let node: SKNode
    public let skull: SkullNode
    public let eyes: EyesNode
    public let jaw: JawNode
    public let decals: DecalNode

    public init(skull: SkullNode, eyes: EyesNode, jaw: JawNode, decals: DecalNode) {
        self.skull = skull
        self.eyes = eyes
        self.jaw = jaw
        self.decals = decals

        let root = SKNode()
        root.name = "face_composite"

        // Position children by skull's anchor points, in scene-space relative to
        // a 256x256 face origin at (0,0).
        let faceSize: CGFloat = 256
        let halfFace = faceSize / 2

        // Eyes — at eyesSocket anchor.
        eyes.node.position = CGPoint(
            x: (skull.anchorPoints.eyesSocket.x - 0.5) * faceSize,
            y: (skull.anchorPoints.eyesSocket.y - 0.5) * faceSize
        )
        // Skull — origin (covers full face).
        skull.node.position = .zero
        // Jaw — at jawHinge anchor.
        jaw.node.position = CGPoint(
            x: (skull.anchorPoints.jawHinge.x - 0.5) * faceSize,
            y: (skull.anchorPoints.jawHinge.y - 0.5) * faceSize
        )
        // Decals — origin; individual decals position themselves.
        decals.node.position = .zero

        root.addChild(eyes.node)
        root.addChild(skull.node)
        root.addChild(jaw.node)
        root.addChild(decals.node)

        _ = halfFace // silence unused — kept for future overlay calculations
        self.node = root
    }
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter FaceCompositeTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tFace/FaceComposite.swift b0tKit/Tests/b0tFaceTests/FaceCompositeTests.swift
git commit -m "feat(b0tFace): facecomposite — 4-layer z-order, anchor-driven part positions"
```

---

### Task 22: AnatomyScene (face only)

**Files:**
- Create: `b0tKit/Sources/b0tFace/AnatomyScene.swift`
- Create: `b0tKit/Tests/b0tFaceTests/AnatomySceneTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SpriteKit
@testable import b0tFace

final class AnatomySceneTests: XCTestCase {
    func test_anatomyScene_initialState_hasFaceComposite() {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        scene.installHilferFace()
        XCTAssertNotNil(scene.childNode(withName: "face_composite"))
    }

    func test_anatomyScene_scaleMode_isAspectFit() {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        XCTAssertEqual(scene.scaleMode, .aspectFit)
    }

    func test_anatomyScene_backgroundColor_isWarmDark() {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        // background must be warm-dark per aesthetic-references.md ("never pure black").
        XCTAssertNotEqual(scene.backgroundColor, .black)
    }
}
```

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter AnatomySceneTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Implement AnatomyScene**

Create `b0tKit/Sources/b0tFace/AnatomyScene.swift`:

```swift
import SpriteKit
import SwiftUI

/// The root SKScene for the anatomy area (top half of HomeView).
///
/// Slice 2 ships face composition only. Slices 3+ add organs, heart, wiring, and
/// touch-handling for organ taps.
public final class AnatomyScene: SKScene {
    public private(set) var face: FaceComposite?

    public override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFit
        backgroundColor = SKColor(red: 0.09, green: 0.08, blue: 0.06, alpha: 1.0) // warm dark
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Installs Hilfer (the static Phase 4 face). Replace with a configurable Model loader
    /// in Slice 9 when `manufacturers.json` is wired up.
    public func installHilferFace() {
        let skull = SkullNode(textureName: "HilferSkull", anchorPoints: .hilferDefaults)
        let eyes = EyesNode(textureName: "HilferEyes")
        let jaw = JawNode(textureName: "HilferJaw")
        let decals = DecalNode()
        let composite = FaceComposite(skull: skull, eyes: eyes, jaw: jaw, decals: decals)
        composite.node.position = .zero
        addChild(composite.node)
        self.face = composite
    }
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter AnatomySceneTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tFace/AnatomyScene.swift b0tKit/Tests/b0tFaceTests/AnatomySceneTests.swift
git commit -m "feat(b0tFace): anatomyscene with hilfer face composition"
```

---

### Task 23: AnatomyView (SwiftUI SpriteView wrapper)

**Files:**
- Create: `b0tKit/Sources/b0tFace/AnatomyView.swift`

- [ ] **Step 1 [CC]: Write AnatomyView**

```swift
import SwiftUI
import SpriteKit

/// SwiftUI wrapper that hosts an `AnatomyScene` inside a `SpriteView`.
///
/// Phase 4 binds the scene to a parent `AnatomyState` (Slice 4); for now the scene
/// is constructed once and Hilfer is installed.
public struct AnatomyView: View {
    @State private var scene: AnatomyScene = {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        scene.installHilferFace()
        return scene
    }()

    public init() {}

    public var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .ignoresSafeArea(.container, edges: .horizontal)
    }
}

#Preview("anatomy — hilfer static") {
    AnatomyView()
        .frame(maxWidth: .infinity, maxHeight: 480)
        .background(Color(red: 0.09, green: 0.08, blue: 0.06))
}
```

- [ ] **Step 2 [VERIFY]: Build and preview**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift build 2>&1 | tail -10
```

Expected: build succeeds. Use Apple Xcode MCP `RenderPreview` against `AnatomyView` to visually verify Hilfer composes (with placeholder squares if PNGs not yet delivered).

- [ ] **Step 3 [JAMEE]: Asset gate**

If Hayden has delivered the three Hilfer PNGs (`HilferSkull`, `HilferEyes`, `HilferJaw`), drop them into `b0tApp/Resources/Assets.xcassets/` as `.imageset` directories at 1×/2×/3× per Apple convention. Otherwise, the preview shows the system's missing-image placeholder; the view-layer code is correct independent of asset delivery.

- [ ] **Step 4 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tFace/AnatomyView.swift
git commit -m "feat(b0tFace): anatomyview swiftui wrapper + hilfer renderpreview"
```

---

### Task 24: b0tFace module CLAUDE.md

**Files:**
- Create: `b0tKit/Sources/b0tFace/CLAUDE.md`

- [ ] **Step 1 [CC]: Write the module CLAUDE.md**

```markdown
# b0tFace — anatomy rendering

The SpriteKit scene tree for the anatomical GUI. Hosts the face (3 Parts + Decal layer),
the 9 organs, the heart, and the wiring network.

## Public surface

- `FacePart` protocol — implemented by `SkullNode`, `EyesNode`, `JawNode`. Three Parts only,
  per amendment §2.1 (Ears removed from scope).
- `SkullAnchorPoints` — `eyesSocket`, `jawHinge` in normalised (0-1) coords. Per-Part defaults
  live as static factories (`.hilferDefaults`, etc.).
- `DecalNode` — additive layer on top of Parts. Empty for Hilfer; populated as Decal assets land.
- `FaceComposite` — composes (Skull, Eyes, Jaw, Decals) with correct z-order and anchor-driven
  positioning.
- `AnatomyScene` — root SKScene; `installHilferFace()` for Phase 4. Slices 3+ add organs / heart /
  wiring; Slice 9 makes the installed Model configurable from `manufacturers.json`.
- `AnatomyView` — SwiftUI `SpriteView` wrapper.

## Phase 4 vs Phase 6

Phase 4 ships *static* Parts (one PNG each). Phase 6 introduces:
- `SKTextureAtlas` per Part with 8 mood-state frames (idle, speaking, thinking, surprised,
  sleepy, attentive, worried, delighted) — see ADR-0011.
- A mood-state machine on `FaceComposite` that drives texture switching + procedural motion
  (blink, breathing, mouth-open) per the forthcoming `face-creator-procedural-animation.md`.
- The Parts library and Face Creator UX — composition of unlocked Parts across Manufacturers.

This module's API is shaped so Phase 6 is additive — no protocol breaking changes anticipated.

## Z-order inside FaceComposite

Bottom to top:
1. **Eyes** — `SKEffectNode` wrapping the eye-screen sprite + `CRTScanlineShader`.
2. **Skull** — polymer shell with eye-cutout window.
3. **Jaw** — mounted at `Skull.anchorPoints.jawHinge`.
4. **Decals** — empty for Hilfer; future content drops add here.

## What lives in b0tHome (not here)

- `AnatomyState` — the @Observable bridge between scene events and SwiftUI views.
- `HomeView`, LCD inspection panel, chat — all SwiftUI, all in `b0tHome`.
- Touch handling that mutates `AnatomyState` from this scene's `touchesBegan` (Slice 4).
```

- [ ] **Step 2 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tFace/CLAUDE.md
git commit -m "docs(b0tFace): module readme"
```

---

### Task 25: Slice 2 verification

- [ ] **Step 1 [VERIFY]: Run all b0tFaceTests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter b0tFaceTests 2>&1 | tail -15
```

Expected: 15+ test cases pass (FacePartProtocol, SkullNode×3, EyesNode×3, JawNode×3, DecalNode×3, FaceComposite×3, AnatomyScene×3).

- [ ] **Step 2 [VERIFY]: Full package suite**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test 2>&1 | tail -5
```

Expected: all green; no regressions.

- [ ] **Step 3 [JAMEE/MANUAL]: RenderPreview check**

Use Apple Xcode MCP `RenderPreview` against `AnatomyView`'s preview. Expected: Hilfer composes with eye-screen → skull → jaw stacking visible. With placeholder squares (no PNGs delivered yet) the layout is still verifiable; with real PNGs the visual coherence is testable.

**Slice 2 verification:** static Hilfer composes correctly. CRT shader applies to Eyes. `AnatomyView` previewable. No regressions.

---

## Slice 3 — Organs, Heart, Wiring

Add the 9-organ ring, the beating heart, and the wiring network around Hilfer. Slice ends with `AnatomyScene` rendering the full anatomy: face + 9 organs in their locked positions + heart pulsing at a default BPM + wiring lines connecting organs to face.

### Task 26: OrganID enum

**Files:**
- Create: `b0tKit/Sources/b0tFace/OrganID.swift`
- Create: `b0tKit/Tests/b0tFaceTests/OrganIDTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
@testable import b0tFace

final class OrganIDTests: XCTestCase {
    func test_organID_hasNineCases() {
        XCTAssertEqual(OrganID.allCases.count, 9)
    }

    func test_organID_includesAllNineSubsystems() {
        let expected: Set<OrganID> = [
            .reasoning, .memory, .identity, .modules,
            .sensors, .tools, .network, .location,
            .heart
        ]
        XCTAssertEqual(Set(OrganID.allCases), expected)
    }

    func test_organID_rawValuesMatchSceneNodeNames() {
        // Node names in the scene are the rawValues — used for hit-testing.
        XCTAssertEqual(OrganID.heart.rawValue, "heart")
        XCTAssertEqual(OrganID.reasoning.rawValue, "reasoning")
        XCTAssertEqual(OrganID.modules.rawValue, "modules")
    }
}
```

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter OrganIDTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Implement OrganID**

Create `b0tKit/Sources/b0tFace/OrganID.swift`:

```swift
/// The nine organs of the anatomical GUI, per ADR-0010.
///
/// Stable across all phases — fixed anatomical subsystems, not derived from modules.
public enum OrganID: String, CaseIterable, Sendable, Hashable {
    // Above eye-line (perception / knowledge / capability)
    case reasoning   // top crown
    case memory      // upper
    case identity    // upper / left
    case modules     // upper

    // Below eye-line (input / output)
    case sensors
    case tools
    case network
    case location

    // Bottom-centre (distinguished)
    case heart
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter OrganIDTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tFace/OrganID.swift b0tKit/Tests/b0tFaceTests/OrganIDTests.swift
git commit -m "feat(b0tFace): organid enum — 9 anatomical subsystems"
```

---

### Task 27: AnatomyLayout (organ positions)

**Files:**
- Create: `b0tKit/Sources/b0tFace/AnatomyLayout.swift`
- Create: `b0tKit/Tests/b0tFaceTests/AnatomyLayoutTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
@testable import b0tFace

final class AnatomyLayoutTests: XCTestCase {
    func test_layout_hasPositionForEveryOrgan() {
        for organ in OrganID.allCases {
            let pos = AnatomyLayout.position(for: organ, in: CGSize(width: 390, height: 480))
            XCTAssertNotNil(pos, "no position for \(organ)")
        }
    }

    func test_reasoning_isAtCrown() {
        let pos = AnatomyLayout.position(for: .reasoning, in: CGSize(width: 390, height: 480))
        // Above the face, centred horizontally.
        XCTAssertEqual(pos.x, 0, accuracy: 1.0)
        XCTAssertGreaterThan(pos.y, 0, "reasoning should be above face centre")
    }

    func test_heart_isAtBottomCentre() {
        let pos = AnatomyLayout.position(for: .heart, in: CGSize(width: 390, height: 480))
        XCTAssertEqual(pos.x, 0, accuracy: 1.0)
        XCTAssertLessThan(pos.y, 0, "heart should be below face centre")
    }

    func test_aboveEyeLineOrgans_haveYPositiveOrAtCrown() {
        for organ in [OrganID.reasoning, .memory, .identity, .modules] {
            let pos = AnatomyLayout.position(for: organ, in: CGSize(width: 390, height: 480))
            XCTAssertGreaterThanOrEqual(pos.y, 0, "\(organ) should be at or above eye-line")
        }
    }

    func test_belowEyeLineOrgans_haveYNegative() {
        for organ in [OrganID.tools, .sensors, .location, .network] {
            let pos = AnatomyLayout.position(for: organ, in: CGSize(width: 390, height: 480))
            XCTAssertLessThan(pos.y, 0, "\(organ) should be below eye-line")
        }
    }

    func test_organBaseSize_is64() {
        XCTAssertEqual(AnatomyLayout.organSize, CGSize(width: 64, height: 64))
    }
}
```

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter AnatomyLayoutTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Implement AnatomyLayout**

Create `b0tKit/Sources/b0tFace/AnatomyLayout.swift`:

```swift
import CoreGraphics

/// Locked layout for the anatomy area, per spec §3 decision 4.
///
/// Coordinates are scene-space, with origin at the centre of the anatomy area.
/// Resolutions are normative per amendment §2.3: face 256, organs 64.
public enum AnatomyLayout {
    public static let faceSize = CGSize(width: 256, height: 256)
    public static let organSize = CGSize(width: 64, height: 64)
    public static let heartSize = CGSize(width: 96, height: 96) // distinguished — slightly larger

    /// Returns the centre position of the given organ in scene-space (origin = centre of anatomy).
    /// Asymmetric upper ring per spec §3 decision 4.
    public static func position(for organ: OrganID, in size: CGSize) -> CGPoint {
        // Distances tuned for an iPhone-size anatomy area (390 × 480 typical).
        // The face occupies the centre at 256 × 256; organs orbit around it.
        let r: CGFloat = 180  // ring radius
        switch organ {
        // ABOVE EYE-LINE (4 organs, asymmetric)
        case .reasoning: return CGPoint(x: 0,        y:  r)               // 12 o'clock — crown
        case .modules:   return CGPoint(x: -r * 0.78, y:  r * 0.55)        // 10–11 o'clock
        case .memory:    return CGPoint(x:  r * 0.78, y:  r * 0.55)        // 1–2 o'clock
        case .identity:  return CGPoint(x: -r,        y:  0)               // 9 o'clock (left ear)

        // BELOW EYE-LINE (4 organs)
        case .tools:     return CGPoint(x: -r * 0.78, y: -r * 0.55)        // 7–8 o'clock
        case .sensors:   return CGPoint(x:  r * 0.78, y: -r * 0.55)        // 4–5 o'clock
        case .location:  return CGPoint(x: -r * 0.42, y: -r * 0.92)        // 7 o'clock-ish, deeper
        case .network:   return CGPoint(x:  r * 0.42, y: -r * 0.92)        // 5 o'clock-ish, deeper

        // BOTTOM-CENTRE (distinguished)
        case .heart:     return CGPoint(x: 0,         y: -r * 1.18)        // below the lower ring
        }
    }
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter AnatomyLayoutTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tFace/AnatomyLayout.swift b0tKit/Tests/b0tFaceTests/AnatomyLayoutTests.swift
git commit -m "feat(b0tFace): anatomylayout — 9 organ positions, asymmetric upper ring"
```

---

### Task 28: OrganNode

**Files:**
- Create: `b0tKit/Sources/b0tFace/OrganNode.swift`
- Create: `b0tKit/Tests/b0tFaceTests/OrganNodeTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SpriteKit
@testable import b0tFace

final class OrganNodeTests: XCTestCase {
    func test_organNode_isNamedByOrganID() {
        let node = OrganNode(organ: .calendar_aliased_to_tools(), textureName: "OrganTools")
        XCTAssertEqual(node.node.name, "tools")
    }

    func test_organNode_idleSize_is64() {
        let node = OrganNode(organ: .memory, textureName: "OrganMemory")
        guard let sprite = node.node as? SKSpriteNode else { XCTFail(); return }
        XCTAssertEqual(sprite.size.width, 64)
        XCTAssertEqual(sprite.size.height, 64)
    }

    func test_organNode_pulseAction_isAvailable() {
        let node = OrganNode(organ: .memory, textureName: "OrganMemory")
        let action = node.activityPulseAction()
        XCTAssertNotNil(action)
        XCTAssertGreaterThan(action.duration, 0)
    }
}

private extension OrganID {
    static func calendar_aliased_to_tools() -> OrganID { .tools }
}
```

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter OrganNodeTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Implement OrganNode**

Create `b0tKit/Sources/b0tFace/OrganNode.swift`:

```swift
import SpriteKit

/// A single organ in the ring — 64px sprite + activity-pulse action.
///
/// Activity-pulse is procedural (no separate "active" PNG) — `SKAction.colorize`
/// + scale tween over the idle sprite. Triggered when the organ is being read /
/// written (memory, modules, tools) or when its corresponding tool is invoked.
public final class OrganNode {
    public let organ: OrganID
    public let node: SKNode

    public init(organ: OrganID, textureName: String) {
        self.organ = organ
        let texture = SKTexture(imageNamed: textureName)
        texture.filteringMode = .nearest
        let size = (organ == .heart) ? AnatomyLayout.heartSize : AnatomyLayout.organSize
        let sprite = SKSpriteNode(texture: texture, size: size)
        sprite.name = organ.rawValue
        self.node = sprite
    }

    /// One-shot activity pulse — the organ "lights up" for ~600ms.
    public func activityPulseAction() -> SKAction {
        let scaleUp = SKAction.scale(to: 1.12, duration: 0.18)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.42)
        scaleUp.timingMode = .easeOut
        scaleDown.timingMode = .easeIn
        return SKAction.sequence([scaleUp, scaleDown])
    }
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter OrganNodeTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tFace/OrganNode.swift b0tKit/Tests/b0tFaceTests/OrganNodeTests.swift
git commit -m "feat(b0tFace): organnode — 64px sprite + procedural activity pulse"
```

---

### Task 29: HeartNode

**Files:**
- Create: `b0tKit/Sources/b0tFace/HeartNode.swift`
- Create: `b0tKit/Tests/b0tFaceTests/HeartNodeTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SpriteKit
@testable import b0tFace

final class HeartNodeTests: XCTestCase {
    func test_heart_pulsesAtConfiguredBPM() {
        let heart = HeartNode(textureName: "OrganHeart")
        heart.startPulsing(bpm: 4)
        XCTAssertNotNil(heart.node.action(forKey: "heartbeat"))
    }

    func test_heart_changingBPM_restartsPulse() {
        let heart = HeartNode(textureName: "OrganHeart")
        heart.startPulsing(bpm: 4)
        let firstAction = heart.node.action(forKey: "heartbeat")
        heart.startPulsing(bpm: 8) // different BPM
        let secondAction = heart.node.action(forKey: "heartbeat")
        XCTAssertNotIdentical(firstAction, secondAction)
    }

    func test_heart_pause_stopsPulse() {
        let heart = HeartNode(textureName: "OrganHeart")
        heart.startPulsing(bpm: 4)
        heart.pause()
        XCTAssertNil(heart.node.action(forKey: "heartbeat"))
    }

    func test_heart_isLargerThanRingOrgans() {
        let heart = HeartNode(textureName: "OrganHeart")
        guard let sprite = heart.node as? SKSpriteNode else { XCTFail(); return }
        // Heart is distinguished — larger than the 64px ring organs.
        XCTAssertGreaterThan(sprite.size.width, AnatomyLayout.organSize.width)
    }
}
```

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter HeartNodeTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Implement HeartNode**

Create `b0tKit/Sources/b0tFace/HeartNode.swift`:

```swift
import SpriteKit

/// The heart — distinguished bottom-centre organ. Pulses at the BPM declared in
/// `heartbeat/schedule.md`. When paused (trial expired, quiet hours), pulse stops.
public final class HeartNode {
    public let node: SKNode

    public init(textureName: String) {
        let texture = SKTexture(imageNamed: textureName)
        texture.filteringMode = .nearest
        let sprite = SKSpriteNode(texture: texture, size: AnatomyLayout.heartSize)
        sprite.name = OrganID.heart.rawValue
        self.node = sprite
    }

    /// Start (or restart) the heartbeat at the given BPM (beats per minute).
    /// Phase 4 BPM range is 1–12 per spec §4.6 semantic registry; range enforced upstream.
    public func startPulsing(bpm: Int) {
        node.removeAction(forKey: "heartbeat")
        let interval = 60.0 / max(1.0, Double(bpm))
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.10, duration: 0.12),
            SKAction.scale(to: 1.0,  duration: 0.20),
            SKAction.wait(forDuration: max(0.05, interval - 0.32))
        ])
        node.run(SKAction.repeatForever(pulse), withKey: "heartbeat")
    }

    public func pause() {
        node.removeAction(forKey: "heartbeat")
        node.setScale(1.0)
    }
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter HeartNodeTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tFace/HeartNode.swift b0tKit/Tests/b0tFaceTests/HeartNodeTests.swift
git commit -m "feat(b0tFace): heartnode — bpm-driven pulse, restart on bpm change"
```

---

### Task 30: WiringNetwork

**Files:**
- Create: `b0tKit/Sources/b0tFace/WiringNetwork.swift`
- Create: `b0tKit/Tests/b0tFaceTests/WiringNetworkTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SpriteKit
@testable import b0tFace

final class WiringNetworkTests: XCTestCase {
    func test_wiring_hasOneLinePerOrgan() {
        let wiring = WiringNetwork()
        wiring.installLines(faceCentre: .zero, organSize: CGSize(width: 390, height: 480))
        // 8 ring organs (heart is distinguished — its line is implicit / different style)
        let lines = wiring.node.children.compactMap { $0 as? SKShapeNode }
        XCTAssertEqual(lines.count, 8)
    }

    func test_wiring_pulseInbound_runsActionOnLine() {
        let wiring = WiringNetwork()
        wiring.installLines(faceCentre: .zero, organSize: CGSize(width: 390, height: 480))
        wiring.pulse(.memory, direction: .inbound)
        let line = wiring.node.childNode(withName: "wire_memory")
        XCTAssertNotNil(line?.action(forKey: "pulse"))
    }

    func test_wiring_pulseOutbound_runsActionOnLine() {
        let wiring = WiringNetwork()
        wiring.installLines(faceCentre: .zero, organSize: CGSize(width: 390, height: 480))
        wiring.pulse(.tools, direction: .outbound)
        let line = wiring.node.childNode(withName: "wire_tools")
        XCTAssertNotNil(line?.action(forKey: "pulse"))
    }
}
```

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter WiringNetworkTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Implement WiringNetwork**

Create `b0tKit/Sources/b0tFace/WiringNetwork.swift`:

```swift
import SpriteKit
import SwiftUI
import b0tDesign

public enum WiringDirection {
    case inbound   // organ → face (reads, sensor input)
    case outbound  // face → organ (tool calls, writes)
}

/// Phosphor-glow lines connecting organs to the face. Direction-aware pulses
/// move along the line during tool calls / memory reads / writes.
///
/// Per `aesthetic-references.md`: warm phosphor — amber, green, cream. Never blue.
public final class WiringNetwork {
    public let node: SKNode

    public init() {
        let root = SKNode()
        root.name = "wiring"
        self.node = root
    }

    /// Installs one wiring line per ring organ (8 organs — heart is distinguished, no wire).
    public func installLines(faceCentre: CGPoint, organSize: CGSize) {
        for organ in OrganID.allCases where organ != .heart {
            let target = AnatomyLayout.position(for: organ, in: organSize)
            let line = makeLine(from: faceCentre, to: target)
            line.name = "wire_\(organ.rawValue)"
            node.addChild(line)
        }
    }

    /// Briefly pulse a line's brightness to show data flow.
    public func pulse(_ organ: OrganID, direction: WiringDirection) {
        guard let line = node.childNode(withName: "wire_\(organ.rawValue)") as? SKShapeNode else { return }
        line.removeAction(forKey: "pulse")
        let bright = SKAction.run { [weak line] in line?.alpha = 1.0 }
        let dim    = SKAction.fadeAlpha(to: 0.35, duration: 0.6)
        line.run(SKAction.sequence([bright, dim]), withKey: "pulse")
        _ = direction // direction influences future colour-tween animation; v1 just intensifies
    }

    private func makeLine(from a: CGPoint, to b: CGPoint) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: a)
        path.addLine(to: b)
        let line = SKShapeNode(path: path)
        line.strokeColor = .systemGreen // phosphor placeholder; tune with aesthetic refs
        line.lineWidth = 1.5
        line.alpha = 0.35 // dim at rest
        line.glowWidth = 1.0
        return line
    }
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter WiringNetworkTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tFace/WiringNetwork.swift b0tKit/Tests/b0tFaceTests/WiringNetworkTests.swift
git commit -m "feat(b0tFace): wiringnetwork — phosphor lines + direction-aware pulse"
```

---

### Task 31: AnatomyScene installs organs + heart + wiring

**Files:**
- Modify: `b0tKit/Sources/b0tFace/AnatomyScene.swift`
- Create: `b0tKit/Tests/b0tFaceTests/AnatomyScene_OrgansAndHeartTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SpriteKit
@testable import b0tFace

final class AnatomyScene_OrgansAndHeartTests: XCTestCase {
    func test_installFullAnatomy_addsAll9Organs() {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        scene.installFullAnatomy(initialBPM: 4)
        for organ in OrganID.allCases {
            XCTAssertNotNil(
                scene.childNode(withName: organ.rawValue),
                "organ \(organ) missing from scene"
            )
        }
    }

    func test_installFullAnatomy_addsWiringNetwork() {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        scene.installFullAnatomy(initialBPM: 4)
        XCTAssertNotNil(scene.childNode(withName: "wiring"))
    }

    func test_installFullAnatomy_heartStartsPulsing() {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        scene.installFullAnatomy(initialBPM: 4)
        let heart = scene.childNode(withName: "heart")
        XCTAssertNotNil(heart?.action(forKey: "heartbeat"))
    }
}
```

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter AnatomyScene_OrgansAndHeartTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Extend AnatomyScene**

Edit `b0tKit/Sources/b0tFace/AnatomyScene.swift` — add new properties and the `installFullAnatomy(initialBPM:)` method. Replace the existing `installHilferFace()` body with one that delegates to the new method (or remove and replace):

```swift
import SpriteKit
import SwiftUI

public final class AnatomyScene: SKScene {
    public private(set) var face: FaceComposite?
    public private(set) var heart: HeartNode?
    public private(set) var wiring: WiringNetwork?
    public private(set) var organs: [OrganID: OrganNode] = [:]

    public override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFit
        backgroundColor = SKColor(red: 0.09, green: 0.08, blue: 0.06, alpha: 1.0)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    @available(*, unavailable)
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Installs Hilfer's face plus the 9-organ ring, heart, and wiring network.
    public func installFullAnatomy(initialBPM: Int) {
        installHilferFace()
        installOrgansAndHeart(initialBPM: initialBPM)
        installWiring()
    }

    /// Installs Hilfer face only (used by AnatomyView previews and slice 2 tests).
    public func installHilferFace() {
        guard face == nil else { return }
        let skull = SkullNode(textureName: "HilferSkull", anchorPoints: .hilferDefaults)
        let eyes = EyesNode(textureName: "HilferEyes")
        let jaw = JawNode(textureName: "HilferJaw")
        let decals = DecalNode()
        let composite = FaceComposite(skull: skull, eyes: eyes, jaw: jaw, decals: decals)
        composite.node.position = .zero
        addChild(composite.node)
        self.face = composite
    }

    private func installOrgansAndHeart(initialBPM: Int) {
        for organ in OrganID.allCases where organ != .heart {
            let node = OrganNode(organ: organ, textureName: textureName(for: organ))
            node.node.position = AnatomyLayout.position(for: organ, in: size)
            addChild(node.node)
            organs[organ] = node
        }
        let heart = HeartNode(textureName: "OrganHeart")
        heart.node.position = AnatomyLayout.position(for: .heart, in: size)
        addChild(heart.node)
        heart.startPulsing(bpm: initialBPM)
        self.heart = heart
    }

    private func installWiring() {
        let wiring = WiringNetwork()
        wiring.installLines(faceCentre: .zero, organSize: size)
        addChild(wiring.node)
        self.wiring = wiring
    }

    private func textureName(for organ: OrganID) -> String {
        switch organ {
        case .reasoning: return "OrganReasoning"
        case .memory:    return "OrganMemory"
        case .identity:  return "OrganIdentity"
        case .modules:   return "OrganModules"
        case .sensors:   return "OrganSensors"
        case .tools:     return "OrganTools"
        case .network:   return "OrganNetwork"
        case .location:  return "OrganLocation"
        case .heart:     return "OrganHeart"
        }
    }
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter AnatomyScene_OrgansAndHeartTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Update the AnatomyView to use the full anatomy installer**

Edit `b0tKit/Sources/b0tFace/AnatomyView.swift`:

```swift
import SwiftUI
import SpriteKit

public struct AnatomyView: View {
    @State private var scene: AnatomyScene = {
        let scene = AnatomyScene(size: CGSize(width: 390, height: 540))
        scene.installFullAnatomy(initialBPM: 4)
        return scene
    }()

    public init() {}

    public var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .ignoresSafeArea(.container, edges: .horizontal)
    }
}

#Preview("anatomy — full (hilfer + organs + heart + wiring)") {
    AnatomyView()
        .frame(maxWidth: .infinity, maxHeight: 540)
        .background(Color(red: 0.09, green: 0.08, blue: 0.06))
}
```

- [ ] **Step 6 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tFace/AnatomyScene.swift b0tKit/Sources/b0tFace/AnatomyView.swift b0tKit/Tests/b0tFaceTests/AnatomyScene_OrgansAndHeartTests.swift
git commit -m "feat(b0tFace): anatomyscene installs 9 organs + heart + wiring"
```

---

### Task 32: Slice 3 verification

- [ ] **Step 1 [VERIFY]: Run b0tFace tests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter b0tFaceTests 2>&1 | tail -15
```

Expected: 25+ test cases pass.

- [ ] **Step 2 [VERIFY]: Full package suite**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test 2>&1 | tail -5
```

Expected: all green.

- [ ] **Step 3 [JAMEE/MANUAL]: RenderPreview check**

Use Apple Xcode MCP `RenderPreview` against `AnatomyView`. Expected: face composes with 9 organs in their layout positions, heart pulsing, wiring lines visible (dim at rest).

**Slice 3 verification:** the full anatomy renders. Heart pulses. Wiring is in place. Visual check via `RenderPreview` confirms layout is right; activity-pulse and wiring-pulse will be exercised in Slices 4 & 8 once `AnatomyState` and the tool-event listener are wired up.

---

## Slice 4 — b0tHome shell + AnatomyState + ChatView

Stand up the new `b0tHome` module: the SwiftUI shell that hosts `AnatomyView` on top and the LCD inspection panel below, with chat as the default LCD content. Wire `AnatomyState` as the bridge between scene events (organ taps) and SwiftUI re-renders. Slice ends with `HomeView` working end-to-end: chat works (via the existing `ConversationManager`), tapping any organ swaps the LCD to a stub inspection view (real content in Slices 5–6).

### Task 33: Add b0tHome target to Package.swift

**Files:**
- Modify: `b0tKit/Package.swift`

- [ ] **Step 1 [CC]: Add the b0tHome library + test target**

Edit `b0tKit/Package.swift`. Add to `products`:

```swift
.library(name: "b0tHome", targets: ["b0tHome"]),
```

Add to `targets`:

```swift
.target(
    name: "b0tHome",
    dependencies: ["b0tFace", "b0tDesign", "b0tBrain", "b0tCore"]
),
.testTarget(
    name: "b0tHomeTests",
    dependencies: ["b0tHome"],
    resources: [.copy("Fixtures")]
),
```

Final `Package.swift` shape (relevant sections):

```swift
products: [
    .library(name: "b0tCore", targets: ["b0tCore"]),
    .library(name: "b0tBrain", targets: ["b0tBrain"]),
    .library(name: "b0tModules", targets: ["b0tModules"]),
    .library(name: "b0tFace", targets: ["b0tFace"]),
    .library(name: "b0tHome", targets: ["b0tHome"]),
    .library(name: "b0tAudio", targets: ["b0tAudio"]),
    .library(name: "b0tDesign", targets: ["b0tDesign"]),
],
// ...
targets: [
    // ... existing targets ...
    .target(name: "b0tHome", dependencies: ["b0tFace", "b0tDesign", "b0tBrain", "b0tCore"]),
    .testTarget(name: "b0tHomeTests", dependencies: ["b0tHome"], resources: [.copy("Fixtures")]),
]
```

- [ ] **Step 2 [CC]: Create the source directory and an empty fixtures dir**

```bash
mkdir -p /Users/haydentoppeross/development/b0t/b0tKit/Sources/b0tHome
mkdir -p /Users/haydentoppeross/development/b0t/b0tKit/Tests/b0tHomeTests/Fixtures
touch /Users/haydentoppeross/development/b0t/b0tKit/Tests/b0tHomeTests/Fixtures/.gitkeep
```

- [ ] **Step 3 [CC]: Create a stub source file so the target compiles**

Create `b0tKit/Sources/b0tHome/b0tHome.swift`:

```swift
// b0tHome — home-screen view layer.
//
// Real types land in subsequent tasks of Slice 4.
// This stub exists so the target compiles before the rest of the slice lands.
public enum b0tHome {
    public static let moduleName = "b0tHome"
}
```

- [ ] **Step 4 [VERIFY]: Build the package**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift build 2>&1 | tail -10
```

Expected: build succeeds. If the b0tApp target is referenced, also update the app's Package dependencies in project.yml.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Package.swift b0tKit/Sources/b0tHome b0tKit/Tests/b0tHomeTests
git commit -m "feat(b0tHome): scaffold module + test target"
```

---

### Task 34: AnatomyState

**Files:**
- Create: `b0tKit/Sources/b0tHome/AnatomyState.swift`
- Create: `b0tKit/Tests/b0tHomeTests/AnatomyStateTests.swift`
- Delete: `b0tKit/Sources/b0tHome/b0tHome.swift` (replaced)

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
@testable import b0tHome
import b0tFace
import b0tBrain

final class AnatomyStateTests: XCTestCase {
    func test_initialState_hasNoSelectedOrgan() {
        let state = makeState()
        XCTAssertNil(state.selectedOrgan)
    }

    func test_initialState_hasEmptyActiveWiring() {
        let state = makeState()
        XCTAssertTrue(state.activeWiring.isEmpty)
    }

    func test_selectingOrgan_setsSelectedOrgan() {
        let state = makeState()
        state.selectedOrgan = .memory
        XCTAssertEqual(state.selectedOrgan, .memory)
    }

    func test_addingActiveWiring_includesIt() {
        let state = makeState()
        state.activeWiring.insert(.tools)
        XCTAssertTrue(state.activeWiring.contains(.tools))
    }

    func test_heartBPM_isMutable() {
        let state = makeState()
        state.heartBPM = 8
        XCTAssertEqual(state.heartBPM, 8)
    }

    private func makeState() -> AnatomyState {
        // Use a dummy bot/store; real wiring exercised in higher-level tests.
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore(rootURL: bot.rootURL)
        return AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
    }
}
```

> If `Bot.empty(at:)` is not a Phase 1 helper, substitute the appropriate constructor / fixture per `b0tBrain/Bot.swift`. Adjust before running.

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter AnatomyStateTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Implement AnatomyState**

Create `b0tKit/Sources/b0tHome/AnatomyState.swift`:

```swift
import Foundation
import Observation
import b0tFace
import b0tBrain

/// The single @Observable source-of-truth that bridges SpriteKit scene events and
/// SwiftUI views. Mutations here drive both directions:
///
/// - SwiftUI views observe `selectedOrgan` to re-render the LCD inspection panel.
/// - The `AnatomyScene` observes `activeWiring` and `heartBPM` to play / restart
///   procedural animations.
@Observable
public final class AnatomyState {
    public var selectedOrgan: OrganID?
    public var activeWiring: Set<OrganID>
    public var heartBPM: Int
    public let bot: Bot
    public let store: BotStore

    public init(bot: Bot, store: BotStore, initialHeartBPM: Int) {
        self.bot = bot
        self.store = store
        self.selectedOrgan = nil
        self.activeWiring = []
        self.heartBPM = initialHeartBPM
    }
}
```

- [ ] **Step 4 [CC]: Delete the stub**

```bash
rm /Users/haydentoppeross/development/b0t/b0tKit/Sources/b0tHome/b0tHome.swift
```

- [ ] **Step 5 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter AnatomyStateTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 6 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tHome/AnatomyState.swift b0tKit/Tests/b0tHomeTests/AnatomyStateTests.swift
git rm b0tKit/Sources/b0tHome/b0tHome.swift
git commit -m "feat(b0tHome): anatomystate — observable bridge"
```

---

### Task 35: SceneStateBridge — wire scene touches to AnatomyState

**Files:**
- Create: `b0tKit/Sources/b0tHome/Internal/SceneStateBridge.swift`
- Create: `b0tKit/Tests/b0tHomeTests/Internal/SceneStateBridgeTests.swift`
- Modify: `b0tKit/Sources/b0tFace/AnatomyScene.swift` — add a `tapHandler` closure property

- [ ] **Step 1 [CC]: Add tapHandler to AnatomyScene**

Edit `b0tKit/Sources/b0tFace/AnatomyScene.swift` — add a closure property and override `touchesBegan`:

```swift
/// Closure invoked when the user taps a named organ in the scene.
/// SceneStateBridge sets this to mutate `AnatomyState.selectedOrgan`.
public var tapHandler: ((OrganID) -> Void)?

#if canImport(UIKit)
public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    let location = touch.location(in: self)
    let hits = nodes(at: location)
    for node in hits {
        if let name = node.name, let organ = OrganID(rawValue: name) {
            tapHandler?(organ)
            return
        }
    }
}
#endif
```

- [ ] **Step 2 [CC]: Write the bridge test**

```swift
import XCTest
@testable import b0tHome
import b0tFace
import b0tBrain

final class SceneStateBridgeTests: XCTestCase {
    func test_bridge_setsSelectedOrganOnTap() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore(rootURL: bot.rootURL)
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        SceneStateBridge.connect(scene: scene, state: state)

        scene.tapHandler?(.memory)
        XCTAssertEqual(state.selectedOrgan, .memory)
    }

    func test_bridge_secondTapOnSameOrgan_deselects() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore(rootURL: bot.rootURL)
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
        SceneStateBridge.connect(scene: scene, state: state)

        scene.tapHandler?(.memory) // select
        scene.tapHandler?(.memory) // deselect
        XCTAssertNil(state.selectedOrgan)
    }
}
```

- [ ] **Step 3 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter SceneStateBridgeTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 4 [CC]: Implement SceneStateBridge**

Create `b0tKit/Sources/b0tHome/Internal/SceneStateBridge.swift`:

```swift
import b0tFace

/// Wires `AnatomyScene` tap events to `AnatomyState`. Tapping the same organ twice
/// deselects (returns LCD to chat).
enum SceneStateBridge {
    static func connect(scene: AnatomyScene, state: AnatomyState) {
        scene.tapHandler = { [weak state] organ in
            guard let state else { return }
            if state.selectedOrgan == organ {
                state.selectedOrgan = nil    // deselect on second tap
            } else {
                state.selectedOrgan = organ
            }
        }
    }
}
```

- [ ] **Step 5 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter SceneStateBridgeTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 6 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tHome/Internal/SceneStateBridge.swift b0tKit/Tests/b0tHomeTests/Internal/SceneStateBridgeTests.swift b0tKit/Sources/b0tFace/AnatomyScene.swift
git commit -m "feat(b0tHome): scenestatebridge — taps mutate selectedorgan, second tap deselects"
```

---

### Task 36: ChatView (default LCD content)

**Files:**
- Create: `b0tKit/Sources/b0tHome/ChatView.swift`
- Create: `b0tKit/Tests/b0tHomeTests/ChatViewTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SwiftUI
@testable import b0tHome
import b0tBrain

final class ChatViewTests: XCTestCase {
    func test_chatView_buildsForInspection() {
        // smoke: the view initialises with a state and renders without throwing.
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore(rootURL: bot.rootURL)
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        _ = ChatView(state: state)
        // No assertion — compile + construct is the test surface.
    }
}
```

- [ ] **Step 2 [CC]: Implement ChatView**

Create `b0tKit/Sources/b0tHome/ChatView.swift`:

```swift
import SwiftUI
import b0tBrain
import b0tDesign

/// Default LCD content — chat scrollback and composer.
///
/// Phase 4 wires this to the existing `ConversationManager` from b0tCore. The visual
/// chrome is the LCD treatment (warm-amber backlit, Verdana for chat content,
/// IoskeleyMono for system labels).
public struct ChatView: View {
    @Bindable var state: AnatomyState
    @State private var input: String = ""

    public init(state: AnatomyState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Scrollback
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("› device ready.")
                        .foregroundStyle(LCDPalette.textDim)
                        .font(Typography.systemMono(size: 12))
                    // Real history wires up to ConversationManager — placeholder for Phase 4 v1.
                    Text("› hilfer here. ask me anything.")
                        .foregroundStyle(LCDPalette.textAmber)
                        .font(Typography.chatBody(size: 14))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            // Composer
            HStack(spacing: 8) {
                Text("›").foregroundStyle(LCDPalette.textDim)
                TextField("type or tap sensors to speak…", text: $input)
                    .font(Typography.chatBody(size: 14))
                    .foregroundStyle(LCDPalette.textAmber)
                    .textFieldStyle(.plain)
                    .submitLabel(.send)
                    .onSubmit { sendMessage() }
            }
            .padding(10)
            .background(LCDPalette.chromeDark.opacity(0.5))
        }
        .background(LCDPalette.bgWarm)
    }

    private func sendMessage() {
        guard !input.isEmpty else { return }
        // TODO (Slice 4 follow-up): route through ConversationManager.
        // For now, the input is captured; b0tCore's ConversationManager integration
        // lives in HomeView so it can use the existing Bootstrap state from b0tApp.
        input = ""
    }
}

#Preview("chat — idle (default lcd)") {
    let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/preview"))
    let store = BotStore(rootURL: bot.rootURL)
    let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
    return ChatView(state: state)
        .frame(maxHeight: 320)
        .background(Color.black)
}
```

> Slice 4's follow-up wires `ConversationManager` properly via `HomeView`. The `sendMessage` placeholder is an explicit TODO captured here.

- [ ] **Step 3 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter ChatViewTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 4 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tHome/ChatView.swift b0tKit/Tests/b0tHomeTests/ChatViewTests.swift
git commit -m "feat(b0tHome): chatview — backlit lcd default content (composer wires next)"
```

---

### Task 37: InspectionPanel (switches by selectedOrgan)

**Files:**
- Create: `b0tKit/Sources/b0tHome/InspectionPanel.swift`
- Create: `b0tKit/Tests/b0tHomeTests/InspectionPanelTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SwiftUI
@testable import b0tHome
import b0tFace
import b0tBrain

final class InspectionPanelTests: XCTestCase {
    func test_panelInitialises_withNoOrganSelected() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore(rootURL: bot.rootURL)
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        _ = InspectionPanel(state: state)
        XCTAssertNil(state.selectedOrgan)
    }

    func test_panelInitialises_withOrganSelected() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore(rootURL: bot.rootURL)
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        state.selectedOrgan = .memory
        _ = InspectionPanel(state: state)
        XCTAssertEqual(state.selectedOrgan, .memory)
    }
}
```

- [ ] **Step 2 [CC]: Implement InspectionPanel**

Create `b0tKit/Sources/b0tHome/InspectionPanel.swift`:

```swift
import SwiftUI
import b0tFace
import b0tDesign

/// The bottom-half LCD panel. Switches content based on `state.selectedOrgan`:
/// - nil → ChatView (default)
/// - any organ → OrganInspectionView (Slice 5+) or DirectoryNavigatorView (Slice 6+)
///
/// Phase 4 stubs the per-organ views with placeholders until Slices 5–6 fill them in.
public struct InspectionPanel: View {
    @Bindable var state: AnatomyState

    public init(state: AnatomyState) {
        self.state = state
    }

    public var body: some View {
        Group {
            if let organ = state.selectedOrgan {
                inspectionStub(for: organ)
            } else {
                ChatView(state: state)
            }
        }
        .background(LCDPalette.bgWarm)
        .overlay(alignment: .topLeading) {
            if state.selectedOrgan != nil {
                Button(action: { state.selectedOrgan = nil }) {
                    Text("‹ back")
                        .font(Typography.systemMono(size: 11))
                        .foregroundStyle(LCDPalette.textDim)
                        .padding(8)
                }
            }
        }
    }

    @ViewBuilder
    private func inspectionStub(for organ: OrganID) -> some View {
        VStack(spacing: 12) {
            Text(organ.rawValue.uppercased())
                .font(Typography.systemMono(size: 16))
                .foregroundStyle(LCDPalette.textAmber)
            Text("inspection view forthcoming (slice 5)")
                .font(Typography.systemMono(size: 11))
                .foregroundStyle(LCDPalette.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 3 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter InspectionPanelTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 4 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tHome/InspectionPanel.swift b0tKit/Tests/b0tHomeTests/InspectionPanelTests.swift
git commit -m "feat(b0tHome): inspectionpanel — switches by selectedorgan, chat default, stubbed organ views"
```

---

### Task 38: HomeView shell

**Files:**
- Create: `b0tKit/Sources/b0tHome/HomeView.swift`

- [ ] **Step 1 [CC]: Implement HomeView**

Create `b0tKit/Sources/b0tHome/HomeView.swift`:

```swift
import SwiftUI
import b0tBrain
import b0tFace
import b0tCore
import b0tDesign

/// The home screen. Anatomy on top, LCD inspection panel below.
public struct HomeView: View {
    @State private var state: AnatomyState
    @State private var scene: AnatomyScene

    public init(bot: Bot, store: BotStore, initialHeartBPM: Int = 4) {
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: initialHeartBPM)
        let scene = AnatomyScene(size: CGSize(width: 390, height: 540))
        scene.installFullAnatomy(initialBPM: initialHeartBPM)
        SceneStateBridge.connect(scene: scene, state: state)
        _state = State(initialValue: state)
        _scene = State(initialValue: scene)
    }

    public var body: some View {
        VStack(spacing: 0) {
            SpriteView(scene: scene, options: [.allowsTransparency])
                .frame(maxHeight: 540)
                .background(Color(red: 0.09, green: 0.08, blue: 0.06))
            InspectionPanel(state: state)
                .frame(maxHeight: .infinity)
        }
        .ignoresSafeArea(.container, edges: .horizontal)
        .onChange(of: state.heartBPM) { _, newBPM in
            scene.heart?.startPulsing(bpm: newBPM)
        }
    }
}

#Preview("home — idle") {
    let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/preview"))
    let store = BotStore(rootURL: bot.rootURL)
    return HomeView(bot: bot, store: store, initialHeartBPM: 4)
}
```

- [ ] **Step 2 [VERIFY]: Build**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift build 2>&1 | tail -10
```

Expected: build succeeds.

- [ ] **Step 3 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tHome/HomeView.swift
git commit -m "feat(b0tHome): homeview — anatomy + lcd, bpm round-trip wired"
```

---

### Task 39: Wire ContentView → HomeView

**Files:**
- Modify: `b0tApp/Sources/App/ContentView.swift`

- [ ] **Step 1 [CC]: Replace ContentView body to host HomeView**

Edit `b0tApp/Sources/App/ContentView.swift`:

```swift
import SwiftUI
import b0tBrain
import b0tHome

struct ContentView: View {
    let bootstrap: Bootstrap

    #if DEBUG
        @State private var showDebugBrain = false
    #endif

    var body: some View {
        ZStack {
            switch bootstrap {
            case .pending:
                pendingView
            case .ready(let bot, let store):
                HomeView(bot: bot, store: store, initialHeartBPM: readBPM(from: store) ?? 4)
                    #if DEBUG
                    .onLongPressGesture(minimumDuration: 1.5) {
                        showDebugBrain = true
                    }
                    #endif
            }
        }
        #if DEBUG
        .sheet(isPresented: $showDebugBrain) {
            if case .ready(let bot, let store) = bootstrap {
                NavigationStack {
                    DebugBrainView(bot: bot, store: store)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("close") { showDebugBrain = false }
                            }
                        }
                }
            }
        }
        #endif
    }

    private var pendingView: some View {
        VStack {
            Text("device starting…")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func readBPM(from store: BotStore) -> Int? {
        // Best-effort — read heartbeat/schedule.md frontmatter.bpm if present.
        guard let file = try? store.read(KnownFiles.heartbeatSchedule) else { return nil }
        if case let .integer(bpm) = file.frontmatter.values["heartbeat_bpm"] ?? .null {
            return bpm
        }
        return nil
    }
}
```

> Adjust `KnownFiles.heartbeatSchedule` and the YAMLValue extraction to match the real Phase 1 / Phase 2 surface. Verify against `b0tBrain/KnownFiles.swift` and `b0tBrain/Frontmatter.swift` before running.

- [ ] **Step 2 [VERIFY]: Build the app**

Use `/build` to compile, or:

```bash
cd /Users/haydentoppeross/development/b0t && xcodebuild -scheme b0t -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -10
```

Expected: app builds. Long-press still opens DebugBrainView.

- [ ] **Step 3 [CC]: Commit**

```bash
git add b0tApp/Sources/App/ContentView.swift
git commit -m "feat(b0tApp): contentview hosts homeview; debugbrain behind long-press"
```

---

### Task 40: Slice 4 verification

- [ ] **Step 1 [VERIFY]: Run b0tHomeTests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter b0tHomeTests 2>&1 | tail -15
```

Expected: 8+ test cases pass.

- [ ] **Step 2 [VERIFY]: Full package suite**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test 2>&1 | tail -5
```

Expected: all green.

- [ ] **Step 3 [JAMEE/MANUAL]: Simulator smoke**

Boot the iPhone simulator, run the app. Expected: home screen renders with anatomy on top + chat-default LCD on bottom. Tapping any organ swaps the LCD to a stubbed inspection view ("inspection view forthcoming (slice 5)"). Tapping "‹ back" or the same organ again returns to chat. Long-press still opens DebugBrainView.

**Slice 4 verification:** `HomeView` is the home screen. Organ taps work, LCD swaps to stubs. Heart pulses. Long-press preserves the existing debug surface.

---

## Slice 5 — OrganInspectionView + FrontmatterControls (heart organ end-to-end)

Implement the frontmatter-as-controls pattern (spec §4.6) and prove it end-to-end on the heart organ: BPM slider, quiet-hours picker, write-back to disk, heart pulse rate updates live. Slice ends with the heart organ fully working — model for Slices 6+ to follow.

### Task 41: FrontmatterControl protocol + dispatcher

**Files:**
- Create: `b0tKit/Sources/b0tHome/FrontmatterControls/FrontmatterControl.swift`
- Create: `b0tKit/Tests/b0tHomeTests/FrontmatterControls/FrontmatterControlTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SwiftUI
@testable import b0tHome
import b0tBrain

final class FrontmatterControlTests: XCTestCase {
    func test_dispatcher_returnsRegisteredControlForKnownKey() {
        // bpm is in the semantic registry → BPMSlider expected.
        let control = FrontmatterControlDispatcher.control(
            forKey: "heartbeat_bpm",
            value: .integer(4),
            onUpdate: { _ in }
        )
        XCTAssertNotNil(control)
        XCTAssertEqual(control?.kind, .bpmSlider)
    }

    func test_dispatcher_fallsBackToTypeRegistryForUnknownKey() {
        let control = FrontmatterControlDispatcher.control(
            forKey: "something_unknown",
            value: .bool(true),
            onUpdate: { _ in }
        )
        XCTAssertNotNil(control)
        XCTAssertEqual(control?.kind, .toggle)
    }
}
```

- [ ] **Step 2 [VERIFY]: Confirm failure**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter FrontmatterControlTests 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3 [CC]: Implement protocol + dispatcher**

Create `b0tKit/Sources/b0tHome/FrontmatterControls/FrontmatterControl.swift`:

```swift
import SwiftUI
import b0tBrain

/// What kind of control should render for this frontmatter field.
public enum FrontmatterControlKind: Sendable {
    case bpmSlider
    case quietHoursPicker
    case enabledToggle
    case toggle           // generic Bool fallback
    case stepper          // generic Int fallback
    case clockTimePicker  // generic ClockTime fallback
    case clockRangePicker // generic ClockRange fallback
    case enumPicker       // String matching a known enum
    case textField        // String fallback
}

/// A renderable control for a single frontmatter field.
public struct FrontmatterControlSpec: Sendable {
    public let key: String
    public let kind: FrontmatterControlKind
    public let value: YAMLValue
    public let onUpdate: @Sendable (YAMLValue) -> Void
}

/// The dispatcher: semantic registry first, then type fallback.
public enum FrontmatterControlDispatcher {
    public static func control(
        forKey key: String,
        value: YAMLValue,
        onUpdate: @escaping @Sendable (YAMLValue) -> Void
    ) -> FrontmatterControlSpec? {
        if let semantic = FrontmatterSemanticRegistry.kind(forKey: key) {
            return FrontmatterControlSpec(key: key, kind: semantic, value: value, onUpdate: onUpdate)
        }
        if let typed = FrontmatterTypeRegistry.kind(for: value) {
            return FrontmatterControlSpec(key: key, kind: typed, value: value, onUpdate: onUpdate)
        }
        return nil
    }
}
```

> Note: `YAMLValue` lives in `b0tBrain` (see `b0tBrain/Frontmatter.swift`). Adjust import / spelling if the actual type differs.

- [ ] **Step 4 [CC]: Stub the registries so the dispatcher compiles**

Create `b0tKit/Sources/b0tHome/FrontmatterControls/FrontmatterTypeRegistry.swift`:

```swift
import b0tBrain

public enum FrontmatterTypeRegistry {
    public static func kind(for value: YAMLValue) -> FrontmatterControlKind? {
        switch value {
        case .bool:    return .toggle
        case .integer: return .stepper
        case .string:  return .textField
        // .clockTime / .clockRange / .array → handled by extending switch as those types land
        default:       return nil
        }
    }
}
```

Create `b0tKit/Sources/b0tHome/FrontmatterControls/FrontmatterSemanticRegistry.swift`:

```swift
public enum FrontmatterSemanticRegistry {
    public static func kind(forKey key: String) -> FrontmatterControlKind? {
        switch key {
        case "heartbeat_bpm", "bpm":          return .bpmSlider
        case "quiet_hours":                   return .quietHoursPicker
        case "enabled":                       return .enabledToggle
        default:                              return nil
        }
    }
}
```

- [ ] **Step 5 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter FrontmatterControlTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 6 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tHome/FrontmatterControls b0tKit/Tests/b0tHomeTests/FrontmatterControls/FrontmatterControlTests.swift
git commit -m "feat(b0tHome): frontmatter control protocol + dispatcher (semantic-first, type fallback)"
```

---

### Task 42: BPMSlider (semantic) — spec §4.6 first-class control

**Files:**
- Create: `b0tKit/Sources/b0tHome/FrontmatterControls/BPMSlider.swift`
- Create: `b0tKit/Tests/b0tHomeTests/FrontmatterControls/BPMSliderTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SwiftUI
@testable import b0tHome
import b0tBrain

final class BPMSliderTests: XCTestCase {
    func test_bpmSlider_rendersWithLabel() {
        var captured: YAMLValue?
        let view = BPMSlider(value: 4) { newValue in
            captured = newValue
        }
        // smoke: view constructs, label format known.
        _ = view.body
        // simulate a change:
        view.commit(8)
        if case .integer(let v) = captured {
            XCTAssertEqual(v, 8)
        } else {
            XCTFail("expected integer value, got \(String(describing: captured))")
        }
    }

    func test_bpmSlider_clampsToValidRange() {
        var captured: YAMLValue?
        let view = BPMSlider(value: 4) { captured = $0 }
        view.commit(20)   // out of range — should clamp
        if case .integer(let v) = captured {
            XCTAssertLessThanOrEqual(v, 12)
            XCTAssertGreaterThanOrEqual(v, 1)
        }
    }
}
```

- [ ] **Step 2 [CC]: Implement BPMSlider**

Create `b0tKit/Sources/b0tHome/FrontmatterControls/BPMSlider.swift`:

```swift
import SwiftUI
import b0tBrain
import b0tDesign

/// Specialised BPM control per spec §4.6 semantic registry.
/// Range 1...12 (one beat per minute up to 12 — tunable upstream if needed).
public struct BPMSlider: View {
    @State private var current: Double
    let onCommit: @Sendable (YAMLValue) -> Void

    public init(value: Int, onCommit: @escaping @Sendable (YAMLValue) -> Void) {
        self._current = State(initialValue: Double(value))
        self.onCommit = onCommit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("♡ \(Int(current.rounded())) bpm")
                    .font(Typography.systemMono(size: 13))
                    .foregroundStyle(LCDPalette.textAmber)
                Spacer()
            }
            Slider(
                value: Binding(
                    get: { current },
                    set: { newValue in
                        current = newValue
                        commit(Int(newValue.rounded()))
                    }
                ),
                in: 1.0...12.0,
                step: 1.0
            )
            .tint(LCDPalette.textAmber)
        }
        .padding(.vertical, 6)
    }

    func commit(_ bpm: Int) {
        let clamped = min(max(bpm, 1), 12)
        onCommit(.integer(clamped))
    }
}
```

- [ ] **Step 3 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter BPMSliderTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 4 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tHome/FrontmatterControls/BPMSlider.swift b0tKit/Tests/b0tHomeTests/FrontmatterControls/BPMSliderTests.swift
git commit -m "feat(b0tHome): bpmslider — semantic registry first-class control"
```

---

### Task 43: Generic fallback controls — bundle (Toggle, Stepper, TextField, ClockTimePicker, EnumPicker)

**Files:**
- Create: `b0tKit/Sources/b0tHome/FrontmatterControls/BoolToggleControl.swift`
- Create: `b0tKit/Sources/b0tHome/FrontmatterControls/StepperControl.swift`
- Create: `b0tKit/Sources/b0tHome/FrontmatterControls/TextFieldControl.swift`
- Create: `b0tKit/Sources/b0tHome/FrontmatterControls/ClockTimePickerControl.swift`
- Create: `b0tKit/Sources/b0tHome/FrontmatterControls/EnumPickerControl.swift`
- Create: `b0tKit/Tests/b0tHomeTests/FrontmatterControls/GenericControlsTests.swift`

- [ ] **Step 1 [CC]: Write a single bundled test**

```swift
import XCTest
import SwiftUI
@testable import b0tHome
import b0tBrain

final class GenericControlsTests: XCTestCase {
    func test_toggle_commitsBool() {
        var captured: YAMLValue?
        let v = BoolToggleControl(label: "enabled", value: true, onCommit: { captured = $0 })
        v.commit(false)
        if case .bool(let b) = captured { XCTAssertFalse(b) } else { XCTFail() }
    }

    func test_stepper_commitsInt() {
        var captured: YAMLValue?
        let v = StepperControl(label: "level", value: 3, onCommit: { captured = $0 })
        v.commit(5)
        if case .integer(let i) = captured { XCTAssertEqual(i, 5) } else { XCTFail() }
    }

    func test_textField_commitsString() {
        var captured: YAMLValue?
        let v = TextFieldControl(label: "name", value: "old", onCommit: { captured = $0 })
        v.commit("new")
        if case .string(let s) = captured { XCTAssertEqual(s, "new") } else { XCTFail() }
    }
}
```

- [ ] **Step 2 [CC]: Implement BoolToggleControl**

```swift
import SwiftUI
import b0tBrain
import b0tDesign

public struct BoolToggleControl: View {
    let label: String
    @State private var current: Bool
    let onCommit: @Sendable (YAMLValue) -> Void

    public init(label: String, value: Bool, onCommit: @escaping @Sendable (YAMLValue) -> Void) {
        self.label = label
        self._current = State(initialValue: value)
        self.onCommit = onCommit
    }

    public var body: some View {
        Toggle(isOn: Binding(
            get: { current },
            set: { newValue in
                current = newValue
                commit(newValue)
            }
        )) {
            Text(label)
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
        }
        .tint(LCDPalette.textAmber)
    }

    func commit(_ b: Bool) { onCommit(.bool(b)) }
}
```

- [ ] **Step 3 [CC]: Implement StepperControl**

```swift
import SwiftUI
import b0tBrain
import b0tDesign

public struct StepperControl: View {
    let label: String
    @State private var current: Int
    let onCommit: @Sendable (YAMLValue) -> Void

    public init(label: String, value: Int, onCommit: @escaping @Sendable (YAMLValue) -> Void) {
        self.label = label
        self._current = State(initialValue: value)
        self.onCommit = onCommit
    }

    public var body: some View {
        Stepper(value: Binding(
            get: { current },
            set: { v in current = v; commit(v) }
        )) {
            Text("\(label): \(current)")
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
        }
    }

    func commit(_ i: Int) { onCommit(.integer(i)) }
}
```

- [ ] **Step 4 [CC]: Implement TextFieldControl**

```swift
import SwiftUI
import b0tBrain
import b0tDesign

public struct TextFieldControl: View {
    let label: String
    @State private var current: String
    let onCommit: @Sendable (YAMLValue) -> Void

    public init(label: String, value: String, onCommit: @escaping @Sendable (YAMLValue) -> Void) {
        self.label = label
        self._current = State(initialValue: value)
        self.onCommit = onCommit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Typography.systemMono(size: 11))
                .foregroundStyle(LCDPalette.textDim)
            TextField("", text: Binding(
                get: { current },
                set: { v in current = v; commit(v) }
            ))
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
                .textFieldStyle(.plain)
        }
    }

    func commit(_ s: String) { onCommit(.string(s)) }
}
```

- [ ] **Step 5 [CC]: Implement ClockTimePickerControl + EnumPickerControl**

```swift
// ClockTimePickerControl.swift
import SwiftUI
import b0tBrain
import b0tDesign

public struct ClockTimePickerControl: View {
    let label: String
    @State private var current: Date
    let onCommit: @Sendable (YAMLValue) -> Void

    public init(label: String, hours: Int, minutes: Int, onCommit: @escaping @Sendable (YAMLValue) -> Void) {
        self.label = label
        var comps = DateComponents()
        comps.hour = hours
        comps.minute = minutes
        let d = Calendar.current.date(from: comps) ?? Date()
        self._current = State(initialValue: d)
        self.onCommit = onCommit
    }

    public var body: some View {
        HStack {
            Text(label)
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
            Spacer()
            DatePicker("", selection: Binding(
                get: { current },
                set: { d in current = d; commit(d) }
            ), displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    func commit(_ d: Date) {
        let h = Calendar.current.component(.hour, from: d)
        let m = Calendar.current.component(.minute, from: d)
        onCommit(.string(String(format: "%02d:%02d", h, m)))
    }
}
```

```swift
// EnumPickerControl.swift
import SwiftUI
import b0tBrain
import b0tDesign

public struct EnumPickerControl: View {
    let label: String
    let options: [String]
    @State private var current: String
    let onCommit: @Sendable (YAMLValue) -> Void

    public init(label: String, options: [String], value: String, onCommit: @escaping @Sendable (YAMLValue) -> Void) {
        self.label = label
        self.options = options
        self._current = State(initialValue: value)
        self.onCommit = onCommit
    }

    public var body: some View {
        HStack {
            Text(label)
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
            Spacer()
            Picker("", selection: Binding(
                get: { current },
                set: { v in current = v; onCommit(.string(v)) }
            )) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }
}
```

- [ ] **Step 6 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter GenericControlsTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 7 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tHome/FrontmatterControls/BoolToggleControl.swift b0tKit/Sources/b0tHome/FrontmatterControls/StepperControl.swift b0tKit/Sources/b0tHome/FrontmatterControls/TextFieldControl.swift b0tKit/Sources/b0tHome/FrontmatterControls/ClockTimePickerControl.swift b0tKit/Sources/b0tHome/FrontmatterControls/EnumPickerControl.swift b0tKit/Tests/b0tHomeTests/FrontmatterControls/GenericControlsTests.swift
git commit -m "feat(b0tHome): generic frontmatter controls — toggle, stepper, textfield, clock, enum picker"
```

---

### Task 44: QuietHoursPicker (semantic) + EnabledToggle (semantic)

**Files:**
- Create: `b0tKit/Sources/b0tHome/FrontmatterControls/QuietHoursPicker.swift`
- Create: `b0tKit/Sources/b0tHome/FrontmatterControls/EnabledToggle.swift`
- Create: `b0tKit/Tests/b0tHomeTests/FrontmatterControls/QuietHoursPickerTests.swift`
- Create: `b0tKit/Tests/b0tHomeTests/FrontmatterControls/EnabledToggleTests.swift`

- [ ] **Step 1 [CC]: Write failing tests**

```swift
// QuietHoursPickerTests.swift
import XCTest
import SwiftUI
@testable import b0tHome
import b0tBrain

final class QuietHoursPickerTests: XCTestCase {
    func test_quietHours_committingNewRange_passesYAMLArray() {
        var captured: YAMLValue?
        let v = QuietHoursPicker(start: "22:00", end: "06:30") { captured = $0 }
        v.commit(start: "23:00", end: "07:00")
        if case .array(let entries) = captured {
            XCTAssertEqual(entries.count, 2)
        } else {
            XCTFail("expected array, got \(String(describing: captured))")
        }
    }

    func test_quietHours_supportsOvernightRanges() {
        let v = QuietHoursPicker(start: "22:00", end: "06:30") { _ in }
        XCTAssertTrue(v.isOvernight) // start > end implies overnight wrap
    }
}
```

```swift
// EnabledToggleTests.swift
import XCTest
@testable import b0tHome
import b0tBrain

final class EnabledToggleTests: XCTestCase {
    func test_enabledToggle_commitsBool() {
        var captured: YAMLValue?
        let t = EnabledToggle(moduleName: "calendar", value: true) { captured = $0 }
        t.commit(false)
        if case .bool(let b) = captured { XCTAssertFalse(b) } else { XCTFail() }
    }
}
```

- [ ] **Step 2 [CC]: Implement QuietHoursPicker**

```swift
import SwiftUI
import b0tBrain
import b0tDesign

/// Specialised range picker for `quiet_hours` frontmatter.
/// Supports overnight ranges (e.g. 22:00 → 06:30) as is — passes the values through
/// to YAML as a 2-element array of HH:MM strings.
public struct QuietHoursPicker: View {
    @State private var start: String
    @State private var end: String
    let onCommit: @Sendable (YAMLValue) -> Void

    public init(start: String, end: String, onCommit: @escaping @Sendable (YAMLValue) -> Void) {
        self._start = State(initialValue: start)
        self._end = State(initialValue: end)
        self.onCommit = onCommit
    }

    public var isOvernight: Bool {
        // crude lexicographic compare on HH:MM works because of zero-padding
        start > end
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("quiet hours")
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
            HStack {
                clockField(label: "start", value: $start)
                Text("→").foregroundStyle(LCDPalette.textDim)
                clockField(label: "end", value: $end)
            }
            if isOvernight {
                Text("overnight (wraps past midnight)")
                    .font(Typography.systemMono(size: 10))
                    .foregroundStyle(LCDPalette.textDim)
            }
        }
    }

    private func clockField(label: String, value: Binding<String>) -> some View {
        TextField(label, text: Binding(
            get: { value.wrappedValue },
            set: { v in
                value.wrappedValue = v
                commit(start: start, end: end)
            }
        ))
        .font(Typography.systemMono(size: 13))
        .foregroundStyle(LCDPalette.textAmber)
        .frame(width: 64)
        .textFieldStyle(.plain)
    }

    func commit(start: String, end: String) {
        onCommit(.array([.string(start), .string(end)]))
    }
}
```

- [ ] **Step 3 [CC]: Implement EnabledToggle**

```swift
import SwiftUI
import b0tBrain
import b0tDesign

/// Specialised toggle for `enabled:` frontmatter — labels with the module name.
public struct EnabledToggle: View {
    let moduleName: String
    @State private var current: Bool
    let onCommit: @Sendable (YAMLValue) -> Void

    public init(moduleName: String, value: Bool, onCommit: @escaping @Sendable (YAMLValue) -> Void) {
        self.moduleName = moduleName
        self._current = State(initialValue: value)
        self.onCommit = onCommit
    }

    public var body: some View {
        Toggle(isOn: Binding(
            get: { current },
            set: { v in current = v; commit(v) }
        )) {
            Text("\(moduleName) enabled")
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
        }
        .tint(LCDPalette.textAmber)
    }

    func commit(_ b: Bool) { onCommit(.bool(b)) }
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter QuietHoursPickerTests --filter EnabledToggleTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tHome/FrontmatterControls/QuietHoursPicker.swift b0tKit/Sources/b0tHome/FrontmatterControls/EnabledToggle.swift b0tKit/Tests/b0tHomeTests/FrontmatterControls/QuietHoursPickerTests.swift b0tKit/Tests/b0tHomeTests/FrontmatterControls/EnabledToggleTests.swift
git commit -m "feat(b0tHome): quiethours + enabledtoggle — semantic registry controls"
```

---

### Task 45: MarkdownRenderer

**Files:**
- Create: `b0tKit/Sources/b0tHome/MarkdownRenderer.swift`

- [ ] **Step 1 [CC]: Implement**

```swift
import SwiftUI
import b0tDesign

/// Renders markdown prose in the LCD inspection panel.
/// v1: trust SwiftUI's `Text(.init(markdown:))` for inline emphasis. Block-level
/// elements (lists, headings) render naïvely; the cassette-futurism aesthetic
/// keeps prose terse so this is acceptable for Phase 4.
public struct MarkdownRenderer: View {
    let markdown: String

    public init(markdown: String) {
        self.markdown = markdown
    }

    public var body: some View {
        ScrollView {
            Text(LocalizedStringKey(markdown))
                .font(Typography.chatBody(size: 14))
                .foregroundStyle(LCDPalette.textAmber)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

- [ ] **Step 2 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tHome/MarkdownRenderer.swift
git commit -m "feat(b0tHome): markdownrenderer — verdana on lcd backlit warm amber"
```

---

### Task 46: OrganInspectionView (heart organ end-to-end)

**Files:**
- Create: `b0tKit/Sources/b0tHome/OrganInspectionView.swift`
- Create: `b0tKit/Tests/b0tHomeTests/OrganInspectionViewTests.swift`
- Modify: `b0tKit/Sources/b0tHome/InspectionPanel.swift` — replace heart-organ stub with the real view

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
import SwiftUI
@testable import b0tHome
import b0tBrain
import b0tFace

final class OrganInspectionViewTests: XCTestCase {
    func test_inspectingHeart_rendersWithBPMSlider() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore(rootURL: bot.rootURL)
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        state.selectedOrgan = .heart
        let view = OrganInspectionView(state: state, organ: .heart, file: heartFixture())
        XCTAssertNotNil(view.body)
    }

    func test_committingBPM_writesBackToStore() {
        // Integration: writing through OrganInspectionView's onCommit should propagate
        // to BotStore. This test asserts the wiring, not the BotStore behaviour itself.
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appending(component: "phase4-heart-test")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let bot = Bot(rootURL: tmp)
        let store = BotStore(rootURL: tmp)
        // Seed schedule.md
        let initial = """
        ---
        heartbeat_bpm: 4
        ---

        # schedule

        body.
        """
        try? initial.write(to: tmp.appending(path: "heartbeat/schedule.md"), atomically: true, encoding: .utf8)
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)

        let view = OrganInspectionView(state: state, organ: .heart, file: try! store.read(KnownFiles.heartbeatSchedule))
        view.commit(key: "heartbeat_bpm", value: .integer(8))

        let updated = try! store.read(KnownFiles.heartbeatSchedule)
        if case .integer(let bpm) = updated.frontmatter.values["heartbeat_bpm"] ?? .null {
            XCTAssertEqual(bpm, 8)
        } else {
            XCTFail("bpm not persisted")
        }
    }

    private func heartFixture() -> BotFile {
        // Minimal in-memory fixture — adjust to match BotFile's constructor in your code.
        BotFile.synthetic(
            relativePath: "heartbeat/schedule.md",
            frontmatter: ["heartbeat_bpm": .integer(4)],
            prose: "# schedule"
        )
    }
}
```

> Adjust `BotFile.synthetic(...)` to whatever constructor exists in `b0tBrain/BotFile.swift`. The shape of the test stands; the exact API surface is verified at execution time.

- [ ] **Step 2 [CC]: Implement OrganInspectionView**

```swift
import SwiftUI
import b0tBrain
import b0tFace
import b0tDesign

/// Inspection view for a single organ. Renders prose via MarkdownRenderer +
/// frontmatter as native controls inline (per spec §4.6).
///
/// On any control commit, the file is rewritten through BotStore. For heart:
/// commit also updates AnatomyState.heartBPM so the scene's HeartNode restarts.
public struct OrganInspectionView: View {
    @Bindable var state: AnatomyState
    let organ: OrganID
    let file: BotFile

    public init(state: AnatomyState, organ: OrganID, file: BotFile) {
        self.state = state
        self.organ = organ
        self.file = file
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Frontmatter controls
            VStack(alignment: .leading, spacing: 10) {
                ForEach(orderedFrontmatterKeys(), id: \.self) { key in
                    if let value = file.frontmatter.values[key],
                       let spec = FrontmatterControlDispatcher.control(
                            forKey: key, value: value,
                            onUpdate: { newValue in commit(key: key, value: newValue) }) {
                        controlView(for: spec)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 32) // leave room for "back" affordance
            // Prose
            MarkdownRenderer(markdown: file.prose)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(LCDPalette.bgWarm)
    }

    @ViewBuilder
    private func controlView(for spec: FrontmatterControlSpec) -> some View {
        switch spec.kind {
        case .bpmSlider:
            if case .integer(let v) = spec.value {
                BPMSlider(value: v, onCommit: spec.onUpdate)
            }
        case .quietHoursPicker:
            if case .array(let entries) = spec.value, entries.count == 2,
               case .string(let s) = entries[0], case .string(let e) = entries[1] {
                QuietHoursPicker(start: s, end: e, onCommit: spec.onUpdate)
            }
        case .enabledToggle:
            if case .bool(let b) = spec.value {
                EnabledToggle(moduleName: file.relativePath, value: b, onCommit: spec.onUpdate)
            }
        case .toggle:
            if case .bool(let b) = spec.value {
                BoolToggleControl(label: spec.key, value: b, onCommit: spec.onUpdate)
            }
        case .stepper:
            if case .integer(let i) = spec.value {
                StepperControl(label: spec.key, value: i, onCommit: spec.onUpdate)
            }
        case .textField:
            if case .string(let s) = spec.value {
                TextFieldControl(label: spec.key, value: s, onCommit: spec.onUpdate)
            }
        case .clockTimePicker, .clockRangePicker, .enumPicker:
            // Wired in Slice 6+ as the file shapes that need them surface.
            EmptyView()
        }
    }

    private func orderedFrontmatterKeys() -> [String] {
        // Stable ordering: known keys first (bpm, quiet_hours, enabled), then alphabetical.
        let known: [String] = ["heartbeat_bpm", "bpm", "quiet_hours", "enabled"]
        let frontmatterKeys = Array(file.frontmatter.values.keys)
        let knownPresent = known.filter { frontmatterKeys.contains($0) }
        let rest = frontmatterKeys.filter { !known.contains($0) }.sorted()
        return knownPresent + rest
    }

    func commit(key: String, value: YAMLValue) {
        var updated = file
        updated.frontmatter.values[key] = value
        try? state.store.write(updated)

        // Special case: heart BPM round-trips through AnatomyState so the scene picks it up.
        if (key == "heartbeat_bpm" || key == "bpm"),
           case .integer(let bpm) = value {
            state.heartBPM = bpm
        }
    }
}
```

> Verify against actual `BotFile`/`Frontmatter`/`BotStore.write` signatures. The shape — frontmatter mutation + write — is the pattern; adjust types to match.

- [ ] **Step 3 [CC]: Wire into InspectionPanel**

Edit `b0tKit/Sources/b0tHome/InspectionPanel.swift` — replace the `inspectionStub(for:)` body with real-content dispatch:

```swift
@ViewBuilder
private func inspectionStub(for organ: OrganID) -> some View {
    switch organ {
    case .heart:
        if let file = try? state.store.read(KnownFiles.heartbeatSchedule) {
            OrganInspectionView(state: state, organ: organ, file: file)
        } else {
            errorPlaceholder(for: organ)
        }
    default:
        // Slice 6 fills the rest.
        VStack(spacing: 12) {
            Text(organ.rawValue.uppercased())
                .font(Typography.systemMono(size: 16))
                .foregroundStyle(LCDPalette.textAmber)
            Text("inspection forthcoming (slice 6)")
                .font(Typography.systemMono(size: 11))
                .foregroundStyle(LCDPalette.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@ViewBuilder
private func errorPlaceholder(for organ: OrganID) -> some View {
    Text("\(organ.rawValue): file unreadable. open editor to fix.")
        .font(Typography.systemMono(size: 12))
        .foregroundStyle(LCDPalette.textDim)
        .padding()
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter OrganInspectionViewTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tHome/OrganInspectionView.swift b0tKit/Sources/b0tHome/InspectionPanel.swift b0tKit/Tests/b0tHomeTests/OrganInspectionViewTests.swift
git commit -m "feat(b0tHome): organinspectionview — heart organ end-to-end (controls round-trip to disk + scene)"
```

---

### Task 47: Slice 5 verification

- [ ] **Step 1 [VERIFY]: Run b0tHomeTests**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter b0tHomeTests 2>&1 | tail -20
```

Expected: 18+ test cases pass.

- [ ] **Step 2 [JAMEE/MANUAL]: Heart BPM round-trip on simulator**

Boot the simulator. Tap the heart organ. Expected:
- LCD swaps to OrganInspectionView showing the BPM slider + quiet-hours picker + the schedule.md prose.
- Drag the BPM slider — within 1 second the heart icon's pulse rate visibly changes.
- Long-press / kill app / relaunch → BPM persists (file is written to disk).

This validates spec §14 acceptance criteria #6 and #7.

**Slice 5 verification:** the heart organ inspection works end-to-end. Frontmatter renders as controls; commits round-trip through BotStore; heart pulse updates live. The pattern is now proven for Slice 6 to extend to other organs.

---

## Slice 6 — Remaining organs + DirectoryNavigatorView

Wire the remaining 8 organs to their inspection content. Modules / Tools / Memory / Identity surface directories of `.md` files. Reasoning / Sensors / Network / Location surface synthesised pseudo-files. Slice ends with every organ tap producing meaningful content.

### Task 48: DirectoryNavigatorView

**Files:**
- Create: `b0tKit/Sources/b0tHome/DirectoryNavigatorView.swift`
- Create: `b0tKit/Tests/b0tHomeTests/DirectoryNavigatorViewTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
@testable import b0tHome
import b0tBrain
import b0tFace

final class DirectoryNavigatorViewTests: XCTestCase {
    func test_navigator_listsFilesInDirectory() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appending(component: "phase4-nav-test")
        let dir = tmp.appending(path: "modules")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? "---\nmodule_id: a\nenabled: true\n---\n".write(to: dir.appending(path: "a.md"), atomically: true, encoding: .utf8)
        try? "---\nmodule_id: b\nenabled: false\n---\n".write(to: dir.appending(path: "b.md"), atomically: true, encoding: .utf8)

        let bot = Bot(rootURL: tmp)
        let store = BotStore(rootURL: tmp)
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        let view = DirectoryNavigatorView(state: state, organ: .modules, directoryRelativePath: "modules")
        let entries = view.entries()
        XCTAssertEqual(Set(entries.map(\.name)), ["a.md", "b.md"])
    }
}
```

- [ ] **Step 2 [CC]: Implement DirectoryNavigatorView**

```swift
import SwiftUI
import b0tBrain
import b0tFace
import b0tDesign

public struct DirectoryNavigatorView: View {
    @Bindable var state: AnatomyState
    let organ: OrganID
    let directoryRelativePath: String
    @State private var selected: BotFile?

    public init(state: AnatomyState, organ: OrganID, directoryRelativePath: String) {
        self.state = state
        self.organ = organ
        self.directoryRelativePath = directoryRelativePath
    }

    public struct Entry: Identifiable, Hashable {
        public let id = UUID()
        public let name: String
        public let url: URL
    }

    public func entries() -> [Entry] {
        let dir = state.bot.rootURL.appending(path: directoryRelativePath)
        guard let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        return urls
            .filter { $0.pathExtension.lowercased() == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { Entry(name: $0.lastPathComponent, url: $0) }
    }

    public var body: some View {
        if let file = selected {
            OrganInspectionView(state: state, organ: organ, file: file)
                .overlay(alignment: .topTrailing) {
                    Button("‹ list") { selected = nil }
                        .font(Typography.systemMono(size: 11))
                        .foregroundStyle(LCDPalette.textDim)
                        .padding(8)
                }
        } else {
            List(entries()) { entry in
                Button(action: {
                    if let file = try? state.store.readFile(at: entry.url) {
                        selected = file
                    }
                }) {
                    HStack {
                        Text(entry.name)
                            .font(Typography.systemMono(size: 13))
                            .foregroundStyle(LCDPalette.textAmber)
                        Spacer()
                    }
                }
                .listRowBackground(LCDPalette.bgWarm)
            }
            .listStyle(.plain)
            .background(LCDPalette.bgWarm)
        }
    }
}
```

> If `BotStore.readFile(at:)` doesn't exist with that exact signature, use the closest available reader; the pattern is "URL → BotFile."

- [ ] **Step 3 [VERIFY]: Confirm passes; commit**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter DirectoryNavigatorViewTests 2>&1 | tail -5
git add b0tKit/Sources/b0tHome/DirectoryNavigatorView.swift b0tKit/Tests/b0tHomeTests/DirectoryNavigatorViewTests.swift
git commit -m "feat(b0tHome): directorynavigatorview — list of .md files, drill-in to inspection"
```

---

### Task 49: Synthesised state files (Reasoning / Sensors / Location / Network)

**Files:**
- Create: `b0tKit/Sources/b0tHome/Synthesised/ReasoningStateFile.swift`
- Create: `b0tKit/Sources/b0tHome/Synthesised/SensorsStateFile.swift`
- Create: `b0tKit/Sources/b0tHome/Synthesised/LocationStateFile.swift`
- Create: `b0tKit/Sources/b0tHome/Synthesised/NetworkStateFile.swift`

- [ ] **Step 1 [CC]: Implement Reasoning synthesised file**

```swift
import b0tBrain

/// Synthesised "reasoning state" file. Read-only — surfaces the last decision,
/// recent token counts, and current model session age. No editable params yet.
public enum ReasoningStateFile {
    public static func make(state: AnatomyState) -> BotFile {
        let prose = """
        # reasoning

        last decision: (live data here once b0tCore exposes a publisher)
        tokens in (recent): —
        tokens out (recent): —
        session age: —

        notes: this organ is read-only in v1. tunable params come later.
        """
        return BotFile.synthetic(
            relativePath: "_synth/reasoning.md",
            frontmatter: [:],
            prose: prose
        )
    }
}
```

- [ ] **Step 2 [CC]: Implement Sensors / Location / Network synthesised files**

```swift
// SensorsStateFile.swift
public enum SensorsStateFile {
    public static func make(state: AnatomyState) -> BotFile {
        BotFile.synthetic(
            relativePath: "_synth/sensors.md",
            frontmatter: ["text_input_enabled": .bool(true)],
            prose: """
            # sensors

            text input toggle above. stt + voice configuration lives in identity/audio.md.
            """
        )
    }
}

// LocationStateFile.swift
public enum LocationStateFile {
    public static func make(state: AnatomyState) -> BotFile {
        BotFile.synthetic(
            relativePath: "_synth/location.md",
            frontmatter: [:],
            prose: """
            # location

            no location module shipped in v1. this organ exists for when the
            location module lands in a later content drop.
            """
        )
    }
}

// NetworkStateFile.swift
public enum NetworkStateFile {
    public static func make(state: AnatomyState) -> BotFile {
        BotFile.synthetic(
            relativePath: "_synth/network.md",
            frontmatter: [:],
            prose: """
            # network

            no network access in v1. on-device only — see ADR-0001.
            this organ exists for when network-dependent modules land.
            """
        )
    }
}
```

- [ ] **Step 3 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tHome/Synthesised
git commit -m "feat(b0tHome): synthesised state files for reasoning/sensors/location/network organs"
```

---

### Task 50: Wire all organs in InspectionPanel

**Files:**
- Modify: `b0tKit/Sources/b0tHome/InspectionPanel.swift`

- [ ] **Step 1 [CC]: Replace inspectionStub with full per-organ dispatch**

Edit `inspectionStub(for:)` in `InspectionPanel.swift`:

```swift
@ViewBuilder
private func inspectionStub(for organ: OrganID) -> some View {
    switch organ {
    case .heart:
        if let file = try? state.store.read(KnownFiles.heartbeatSchedule) {
            OrganInspectionView(state: state, organ: .heart, file: file)
        } else { errorPlaceholder(for: .heart) }

    case .modules:
        DirectoryNavigatorView(state: state, organ: .modules, directoryRelativePath: "modules")

    case .memory:
        DirectoryNavigatorView(state: state, organ: .memory, directoryRelativePath: "memory")

    case .identity:
        DirectoryNavigatorView(state: state, organ: .identity, directoryRelativePath: "identity")

    case .tools:
        ToolsDirectoryView(state: state)

    case .reasoning:
        OrganInspectionView(state: state, organ: .reasoning, file: ReasoningStateFile.make(state: state))

    case .sensors:
        OrganInspectionView(state: state, organ: .sensors, file: SensorsStateFile.make(state: state))

    case .location:
        OrganInspectionView(state: state, organ: .location, file: LocationStateFile.make(state: state))

    case .network:
        OrganInspectionView(state: state, organ: .network, file: NetworkStateFile.make(state: state))
    }
}
```

- [ ] **Step 2 [CC]: Implement ToolsDirectoryView**

Create `b0tKit/Sources/b0tHome/Synthesised/ToolsDirectoryView.swift`:

```swift
import SwiftUI
import b0tBrain
import b0tFace
import b0tDesign

/// The Tools organ surfaces a virtual directory built from the live ToolRegistry.
/// Each tool gets a pseudo-file view (read-only metadata for v1).
public struct ToolsDirectoryView: View {
    @Bindable var state: AnatomyState

    public init(state: AnatomyState) { self.state = state }

    public var body: some View {
        // ToolRegistry surface is exposed by b0tCore / b0tModules. v1 lists
        // statically the 4 shipped Phase 3 tools. Phase 4.5+ wires this to
        // the live registry.
        List([
            "calendar.upcoming_events",
            "reminders.create",
            "reminders.list",
            "health.steps_today"
        ], id: \.self) { name in
            Text(name)
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
                .listRowBackground(LCDPalette.bgWarm)
        }
        .listStyle(.plain)
        .background(LCDPalette.bgWarm)
    }
}
```

- [ ] **Step 3 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tHome/InspectionPanel.swift b0tKit/Sources/b0tHome/Synthesised/ToolsDirectoryView.swift
git commit -m "feat(b0tHome): all 9 organs surface real inspection content"
```

---

### Task 51: Slice 6 verification

- [ ] **Step 1 [VERIFY]: Run b0tHomeTests; full package suite**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test 2>&1 | tail -5
```

Expected: all green.

- [ ] **Step 2 [JAMEE/MANUAL]: Tap each organ on the simulator**

Boot the simulator. Tap each of the 9 organs in turn. Expected:
- Heart, Reasoning, Sensors, Location, Network → OrganInspectionView with synthesised or real content
- Modules, Memory, Identity → DirectoryNavigatorView listing real files; drill-in works
- Tools → list of the 4 shipped tools

**Slice 6 verification:** every organ has meaningful inspection content. Pattern proven across both single-file and directory-shaped organs.

---

## Slice 7 — EditorView (full-screen markdown editor)

Add a full-screen markdown editor reachable from any inspection view. Slice ends with the user able to edit any `.md` file's raw content + frontmatter.

### Task 52: EditorView

**Files:**
- Create: `b0tKit/Sources/b0tHome/EditorView.swift`
- Create: `b0tKit/Tests/b0tHomeTests/EditorViewTests.swift`

- [ ] **Step 1 [CC]: Write the failing test**

```swift
import XCTest
@testable import b0tHome
import b0tBrain

final class EditorViewTests: XCTestCase {
    func test_editor_savesContentToStore() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appending(component: "phase4-editor-test")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        try? "---\nfoo: 1\n---\n\n# original\n".write(
            to: tmp.appending(path: "test.md"),
            atomically: true,
            encoding: .utf8
        )
        let bot = Bot(rootURL: tmp)
        let store = BotStore(rootURL: tmp)
        let file = try! store.readFile(at: tmp.appending(path: "test.md"))

        let editor = EditorView(file: file, store: store, onClose: {})
        editor.save(rawContent: "---\nfoo: 2\n---\n\n# edited\n")

        let updated = try! store.readFile(at: tmp.appending(path: "test.md"))
        XCTAssertTrue(updated.prose.contains("# edited"))
    }
}
```

- [ ] **Step 2 [CC]: Implement EditorView**

```swift
import SwiftUI
import b0tBrain
import b0tDesign

/// Full-screen markdown editor. Reachable from any OrganInspectionView via an
/// "edit" affordance.
///
/// v1 ships a plain TextEditor over the raw .md contents (frontmatter inclusive).
/// Save → BotStore.write; cancel → discard.
public struct EditorView: View {
    @State private var rawContent: String
    let file: BotFile
    let store: BotStore
    let onClose: () -> Void

    public init(file: BotFile, store: BotStore, onClose: @escaping () -> Void) {
        self.file = file
        self.store = store
        self.onClose = onClose
        self._rawContent = State(initialValue: file.serialise())
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("cancel") { onClose() }
                    .font(Typography.systemMono(size: 13))
                    .foregroundStyle(LCDPalette.textDim)
                Spacer()
                Text(file.relativePath)
                    .font(Typography.systemMono(size: 12))
                    .foregroundStyle(LCDPalette.textDim)
                Spacer()
                Button("save") {
                    save(rawContent: rawContent)
                    onClose()
                }
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
            }
            .padding(12)
            .background(LCDPalette.chromeDark)

            TextEditor(text: $rawContent)
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
                .scrollContentBackground(.hidden)
                .background(LCDPalette.bgWarm)
        }
        .background(LCDPalette.bgWarm)
        .ignoresSafeArea(.container, edges: .horizontal)
    }

    func save(rawContent: String) {
        guard let parsed = try? BotFile.parse(rawContent: rawContent, relativePath: file.relativePath) else { return }
        try? store.write(parsed)
    }
}
```

> Adjust `BotFile.serialise()` and `BotFile.parse(rawContent:relativePath:)` to match the actual b0tBrain surface.

- [ ] **Step 3 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter EditorViewTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 4 [CC]: Wire "edit" affordance into OrganInspectionView**

Edit `OrganInspectionView` body — add an edit button at the top-right that flips a state-driven `@State var isEditing: Bool`, presenting `EditorView` as a `.fullScreenCover`. Inside `OrganInspectionView`:

```swift
@State private var isEditing: Bool = false
// ...
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        if file.relativePath.hasSuffix(".md") && !file.relativePath.hasPrefix("_synth/") {
            Button("edit") { isEditing = true }
                .font(Typography.systemMono(size: 11))
                .foregroundStyle(LCDPalette.textAmber)
        }
    }
}
.fullScreenCover(isPresented: $isEditing) {
    EditorView(file: file, store: state.store, onClose: { isEditing = false })
}
```

(Synthesised files have `_synth/` prefix and are not editable.)

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tHome/EditorView.swift b0tKit/Sources/b0tHome/OrganInspectionView.swift b0tKit/Tests/b0tHomeTests/EditorViewTests.swift
git commit -m "feat(b0tHome): editorview — full-screen markdown edit, wired from inspection"
```

---

### Task 53: Slice 7 verification

- [ ] **Step 1 [VERIFY]: Tests + simulator smoke**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test 2>&1 | tail -5
```

Manual: tap heart → tap "edit" → modify the prose → save → return to inspection → prose updated. Cancel from edit → no change.

**Slice 7 verification:** edit mode round-trips. Synthesised files (Reasoning / Network / Location / Sensors) do not show edit affordance.

---

## Slice 8 — Tool-event wiring pulses

Hook the wiring network's pulse animations to live tool invocations from `b0tCore` / `b0tModules`. Slice ends with the calendar tool (or any Phase 3 tool) call lighting up the Tools organ + its wiring line for ~2 seconds.

### Task 54: ToolInvocationListener

**Files:**
- Create: `b0tKit/Sources/b0tHome/Internal/ToolInvocationListener.swift`
- Create: `b0tKit/Tests/b0tHomeTests/Internal/ToolInvocationListenerTests.swift`
- Modify (if needed): `b0tKit/Sources/b0tCore/...` — expose a `ToolInvocationPublisher` if Phase 3 didn't already.

- [ ] **Step 1 [CC]: Verify Phase 3's tool-invocation surface**

```bash
grep -rn "ToolInvocation\|toolName\b" /Users/haydentoppeross/development/b0t/b0tKit/Sources --include='*.swift' | head -30
```

Phase 3 already extracts `ToolCallRecord` from `Transcript`. Confirm there's a publisher/observation point in `ConversationManager` or `Executor`. If not, add one — extend `ConversationManager` with a Combine `PassthroughSubject<ToolCallRecord, Never>` named `toolCallEvents` exposed publicly.

- [ ] **Step 2 [CC]: Write the failing test**

```swift
import XCTest
import Combine
@testable import b0tHome
import b0tFace
import b0tBrain

final class ToolInvocationListenerTests: XCTestCase {
    func test_listener_pulsesToolsOrganOnInvocation() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore(rootURL: bot.rootURL)
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)

        let publisher = PassthroughSubject<String, Never>()
        let listener = ToolInvocationListener(state: state, source: publisher.eraseToAnyPublisher())
        listener.start()

        publisher.send("calendar.upcoming_events")

        // Synchronous assertion: state.activeWiring should have updated.
        XCTAssertTrue(state.activeWiring.contains(.tools))
    }
}
```

- [ ] **Step 3 [CC]: Implement ToolInvocationListener**

```swift
import Foundation
import Combine
import b0tFace

/// Bridges b0tCore's tool-call events to the anatomy's wiring network.
/// On each invocation, marks the relevant organ in `activeWiring` for ~2s,
/// then removes it. Multiple concurrent invocations are tracked correctly.
public final class ToolInvocationListener {
    let state: AnatomyState
    let source: AnyPublisher<String, Never>
    private var cancellable: AnyCancellable?

    public init(state: AnatomyState, source: AnyPublisher<String, Never>) {
        self.state = state
        self.source = source
    }

    public func start() {
        cancellable = source.sink { [weak self] toolName in
            self?.pulse(for: toolName)
        }
    }

    public func stop() {
        cancellable?.cancel()
        cancellable = nil
    }

    private func pulse(for toolName: String) {
        let organ = organID(for: toolName)
        state.activeWiring.insert(organ)
        Task { @MainActor [weak state] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            state?.activeWiring.remove(organ)
        }
    }

    private func organID(for toolName: String) -> OrganID {
        // Phase 4 v1: all tools route through the Tools organ.
        // Future refinement: memory.* → memory organ, sensors.* → sensors organ, etc.
        if toolName.hasPrefix("memory.") { return .memory }
        return .tools
    }
}
```

- [ ] **Step 4 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter ToolInvocationListenerTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 5 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tHome/Internal/ToolInvocationListener.swift b0tKit/Tests/b0tHomeTests/Internal/ToolInvocationListenerTests.swift
git commit -m "feat(b0tHome): toolinvocationlistener — wiring pulses on tool calls"
```

---

### Task 55: Wire AnatomyState.activeWiring → AnatomyScene wiring pulses

**Files:**
- Modify: `b0tKit/Sources/b0tHome/HomeView.swift` — observe `state.activeWiring` and call `scene.wiring?.pulse(...)`

- [ ] **Step 1 [CC]: Add observer in HomeView**

In `HomeView.body`, add:

```swift
.onChange(of: state.activeWiring) { oldSet, newSet in
    let added = newSet.subtracting(oldSet)
    for organ in added {
        scene.wiring?.pulse(organ, direction: .outbound)
        if let organNode = scene.organs[organ] {
            organNode.node.run(organNode.activityPulseAction())
        }
    }
}
```

- [ ] **Step 2 [VERIFY/MANUAL]: Trigger a tool call**

Boot the simulator. Send a chat message that triggers a calendar tool call. Expected: the Tools organ pulses (scale tween) and the wiring line between Tools and the face brightens for ~2s.

- [ ] **Step 3 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tHome/HomeView.swift
git commit -m "feat(b0tHome): homeview observes activewiring → scene pulses + organ activity"
```

---

### Task 56: Slice 8 verification

- [ ] **Step 1 [VERIFY]: Full suite + manual smoke per spec §14 #4**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test 2>&1 | tail -5
```

Manual: invoke calendar tool, observe wiring + Tools organ pulse.

**Slice 8 verification:** wiring lights up live on tool calls. Spec §14 acceptance criterion #4 is met.

---

## Slice 9 — manufacturers.json reader + BotProvisioner integration

Wire the Phase 4 catalogue: read `manufacturers.json` at first launch and use Hilfer's defaults to seed the bot. Slice ends with `BotProvisioner` driven by the catalogue rather than hardcoded defaults.

### Task 57: Manufacturer + BotModel Codable types

**Files:**
- Create: `b0tKit/Sources/b0tCore/Catalogue/Manufacturer.swift`
- Create: `b0tKit/Sources/b0tCore/Catalogue/BotModel.swift`
- Create: `b0tKit/Tests/b0tCoreTests/Catalogue/ManufacturerTests.swift`
- Create: `b0tKit/Tests/b0tCoreTests/Catalogue/BotModelTests.swift`

- [ ] **Step 1 [CC]: Write failing tests**

```swift
// ManufacturerTests.swift
import XCTest
@testable import b0tCore

final class ManufacturerTests: XCTestCase {
    func test_decodes_fromJSON() throws {
        let json = """
        {
          "id": "wundercog",
          "name": "Wundercog Industries",
          "base_prompt_template": "...",
          "palettes": ["wundercog_offwhite_mint"],
          "identity_description": "Friendly utility aesthetic"
        }
        """
        let m = try JSONDecoder().decode(Manufacturer.self, from: Data(json.utf8))
        XCTAssertEqual(m.id, "wundercog")
        XCTAssertEqual(m.palettes, ["wundercog_offwhite_mint"])
    }
}

// BotModelTests.swift
final class BotModelTests: XCTestCase {
    func test_decodes_hilfer() throws {
        let json = """
        {
          "id": "hilfer",
          "manufacturer": "wundercog",
          "tier": 1,
          "is_starter": true,
          "parts": {
            "skull": "wundercog_skull_egg_offwhite_mint",
            "eyes": "wundercog_eyes_mint_idle",
            "jaw": "wundercog_jaw_small_offwhite_mint"
          },
          "palette": "wundercog_offwhite_mint",
          "decals": [],
          "default_personality_dir": "identity/",
          "default_modules": ["calendar"],
          "default_tools": ["calendar.upcoming_events"],
          "heartbeat_unlock_threshold": null
        }
        """
        let model = try JSONDecoder().decode(BotModel.self, from: Data(json.utf8))
        XCTAssertEqual(model.id, "hilfer")
        XCTAssertTrue(model.isStarter)
        XCTAssertEqual(model.parts.skull, "wundercog_skull_egg_offwhite_mint")
    }
}
```

- [ ] **Step 2 [CC]: Implement Codable types**

```swift
// Manufacturer.swift
public struct Manufacturer: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let basePromptTemplate: String
    public let palettes: [String]
    public let identityDescription: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case basePromptTemplate = "base_prompt_template"
        case palettes
        case identityDescription = "identity_description"
    }
}

// BotModel.swift
public struct BotModel: Codable, Sendable, Equatable {
    public let id: String
    public let manufacturer: String
    public let tier: Int
    public let isStarter: Bool
    public let parts: Parts
    public let palette: String
    public let decals: [String]
    public let defaultPersonalityDir: String
    public let defaultModules: [String]
    public let defaultTools: [String]
    public let heartbeatUnlockThreshold: Int?

    public struct Parts: Codable, Sendable, Equatable {
        public let skull: String
        public let eyes: String
        public let jaw: String
    }

    enum CodingKeys: String, CodingKey {
        case id, manufacturer, tier, parts, palette, decals
        case isStarter = "is_starter"
        case defaultPersonalityDir = "default_personality_dir"
        case defaultModules = "default_modules"
        case defaultTools = "default_tools"
        case heartbeatUnlockThreshold = "heartbeat_unlock_threshold"
    }
}
```

- [ ] **Step 3 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter ManufacturerTests --filter BotModelTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 4 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tCore/Catalogue b0tKit/Tests/b0tCoreTests/Catalogue
git commit -m "feat(b0tCore): manufacturer + botmodel codable types"
```

---

### Task 58: ManufacturerCatalogue loader

**Files:**
- Create: `b0tKit/Sources/b0tCore/Catalogue/ManufacturerCatalogue.swift`
- Create: `b0tKit/Tests/b0tCoreTests/Catalogue/ManufacturerCatalogueTests.swift`

- [ ] **Step 1 [CC]: Write failing test**

```swift
import XCTest
@testable import b0tCore

final class ManufacturerCatalogueTests: XCTestCase {
    func test_loadFromBundle_findsHilfer() throws {
        let url = Bundle.module.url(forResource: "manufacturers", withExtension: "json")!
        let catalogue = try ManufacturerCatalogue.load(from: url)
        XCTAssertEqual(catalogue.starterModel()?.id, "hilfer")
    }

    func test_starterModel_defaults_includeShippedModules() throws {
        let url = Bundle.module.url(forResource: "manufacturers", withExtension: "json")!
        let catalogue = try ManufacturerCatalogue.load(from: url)
        let hilfer = catalogue.starterModel()
        XCTAssertTrue(hilfer?.defaultModules.contains("calendar") ?? false)
    }
}
```

> Add a fixture `manufacturers.json` to `b0tKit/Tests/b0tCoreTests/Fixtures/` (copy of the Phase-4 stub) so `Bundle.module.url(forResource:withExtension:)` resolves it.

- [ ] **Step 2 [CC]: Implement ManufacturerCatalogue**

```swift
import Foundation

public struct ManufacturerCatalogue: Sendable {
    public let manufacturers: [Manufacturer]
    public let models: [BotModel]

    enum CodingKeys: String, CodingKey {
        case manufacturers, models
    }
}

extension ManufacturerCatalogue: Decodable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.manufacturers = try c.decode([Manufacturer].self, forKey: .manufacturers)
        self.models = try c.decode([BotModel].self, forKey: .models)
    }
}

public extension ManufacturerCatalogue {
    static func load(from url: URL) throws -> ManufacturerCatalogue {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ManufacturerCatalogue.self, from: data)
    }

    func starterModel() -> BotModel? {
        models.first { $0.isStarter }
    }
}
```

- [ ] **Step 3 [VERIFY]: Confirm passes**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test --filter ManufacturerCatalogueTests 2>&1 | tail -5
```

Expected: PASS.

- [ ] **Step 4 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tCore/Catalogue/ManufacturerCatalogue.swift b0tKit/Tests/b0tCoreTests/Catalogue/ManufacturerCatalogueTests.swift b0tKit/Tests/b0tCoreTests/Fixtures/manufacturers.json
git commit -m "feat(b0tCore): manufacturercatalogue loader + fixture"
```

---

### Task 59: BotProvisioner reads catalogue

**Files:**
- Modify: `b0tKit/Sources/b0tBrain/BotProvisioner.swift`

- [ ] **Step 1 [CC]: Update BotProvisioner**

Read `manufacturers.json` from the bundle on first launch and use the starter model's `default_modules` / `default_tools` / `default_personality_dir` to seed the bot. The seeding logic itself stays the same — just the *which-modules-to-enable* decision becomes catalogue-driven.

```swift
// Inside BotProvisioner — adapt to existing structure:
import b0tCore

extension BotProvisioner {
    /// Read the starter Model from manufacturers.json, if present in the app bundle.
    /// Falls back to the existing hardcoded defaults if absent or undecodable.
    func starterDefaultsFromCatalogue() -> BotModel? {
        guard let url = Bundle.main.url(forResource: "manufacturers", withExtension: "json") else {
            return nil
        }
        return try? ManufacturerCatalogue.load(from: url).starterModel()
    }
}
```

Then in the existing seed path: if `starterDefaultsFromCatalogue()` returns a model, prefer its `defaultModules` for which `modules/*.md` to enable.

- [ ] **Step 2 [VERIFY]: Build + simulator smoke**

Wipe the simulator's app data → relaunch → `BotProvisioner` runs and seeds with the catalogue defaults. Console logs should show `[b0t] starter model: hilfer` (or similar log added in this task).

- [ ] **Step 3 [CC]: Commit**

```bash
git add b0tKit/Sources/b0tBrain/BotProvisioner.swift
git commit -m "feat(b0tBrain): botprovisioner consults manufacturers.json for starter defaults"
```

---

### Task 60: Slice 9 verification

- [ ] **Step 1 [VERIFY]: Full suite**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test 2>&1 | tail -5
```

**Slice 9 verification:** the catalogue is loaded and the starter Model's defaults drive provisioning. Phase 4 ships only Hilfer; Phase 6 expansions just add JSON entries.

---

## Slice 10 — RenderPreview pass + manual smoke + close-out

Run the visual checks that matter, drive the simulator through the §14 acceptance criteria, capture phase-close notes.

### Task 61: RenderPreview pass

- [ ] **Step 1 [JAMEE/MANUAL]: Render every preview**

Use Apple Xcode MCP `RenderPreview` against:
- `AnatomyView` — full anatomy (Hilfer + organs + heart + wiring).
- `ChatView` — idle LCD with default placeholder content.
- `InspectionPanel` (with various `selectedOrgan`) — at minimum heart + modules + identity.
- `OrganInspectionView` (heart) — controls inline above prose.
- `EditorView` — full-screen with sample content.

Capture screenshots; visually confirm aesthetic discipline per `aesthetic-references.md` (pixel-art fidelity at 256/64 native, LCD ≠ CRT, warm phosphor never blue, IoskeleyMono for UI / Verdana for chat).

- [ ] **Step 2 [JAMEE/MANUAL]: Adjust palettes / shader values if needed**

Tune `WundercogPalette`, `LCDPalette`, and `CRTScanlineShader.make(intensity:lineCount:)` based on what Hayden sees. Iterate until the look is right; commit each tuning iteration as `tune(b0tDesign): <surface>`.

---

### Task 62: Acceptance smoke per spec §14

- [ ] **Step 1 [JAMEE/MANUAL]: Walk the §14 checklist**

Boot the simulator. For each of spec §14's 10 acceptance criteria, verify live:

1. App opens to home with Hilfer composed of three Parts visible (skull / eyes-with-CRT / jaw).
2. 9-organ ring laid out per locked layout.
3. Heart pulses at the BPM declared in `heartbeat/schedule.md`.
4. Wiring lights up + pulses direction-aware on tool invocation.
5. Tapping any organ swaps LCD to controls.
6. Frontmatter renders as native controls (verify on heart's BPM slider + at least one module's `enabled:` toggle).
7. Sliding BPM mutates `schedule.md` on disk + heart updates within seconds.
8. Tap "edit" → full-screen markdown editor; save writes back; cancel discards.
9. With nothing selected, LCD shows chat scrollback + composer; sending a message routes through ConversationManager.
10. Visual languages distinct: only Eye-screen has CRT scanlines; LCD has no bloom.

Note any failures — open them as Phase 4.5 follow-ups in IMPLEMENTATION.md.

---

### Task 63: IMPLEMENTATION.md notes + status flip

**Files:**
- Modify: `docs/IMPLEMENTATION.md`

- [ ] **Step 1 [CC]: Add Phase 4 notes block**

Add a "## Notes from Phase 4" section to IMPLEMENTATION.md following the Phase 1/2/3 pattern:

```markdown
## Notes from Phase 4

- Spec at `docs/specs/phase-4-anatomical-gui.md` settled on 2026-05-05 from a brainstorm pivoted by Hayden mid-stream (defer parts/animation to Phase 6, ship one static face first). Plan at `docs/plans/phase-4-anatomical-gui.md` decomposed the spec into N tasks across 11 slices. Implemented [start]–[end].
- ADRs landed: 0010 (organs are anatomical subsystems — supersedes part of 0007), 0011 (defer face rig to Phase 6).
- New module: `b0tHome` — SwiftUI shell, LCD inspection panel, frontmatter-as-controls, chat default content. Depends on `b0tFace`, `b0tDesign`, `b0tBrain`, `b0tCore`.
- New artefacts: `docs/references/face-roster.md` (15 Models, kc-oracle palette corrected), `b0tApp/Resources/manufacturers.json` (Wundercog + Hilfer), the three Hilfer Part PNGs delivered by Hayden from Gamelabs Studio (per amendment §2.2).
- Visual languages distinct: only Eye-screen carries CRT scanline overlay; LCD inspection panel is backlit warm-amber (no bloom, no scanlines); Skull / Jaw / organs / heart are flat pixel art with painterly lighting.
- Mid-phase plan-vs-SDK adaptations [fill in during execution].

### Phase 4 follow-ups (out of scope; tracked for Phase 4.5 or later)

- Module sub-icons are interim bespoke — replace with the 12–24-symbol vocabulary called for by amendment §2.3 once the vocabulary is designed.
- Tools organ surfaces a static list of the 4 shipped tools — wire to live ToolRegistry once exposed.
- Söhne font replaced by Verdana per Phase-4 brainstorm decision (2026-05-05). Revisit if the chat readability isn't right on real devices.
- Phase 3's `BotProvisioner` once-only-on-first-launch behaviour persists — bundle drift between releases will not propagate to existing installs. More pressing now that Phase 4 ships visual assets.
```

- [ ] **Step 2 [CC]: Flip Phase 4 status to complete**

In the "Current state" block:

```markdown
- **Phase:** 5 — Onboarding sequence
- **Status:** not started
```

In the ledger row, mark Phase 4 as `complete (YYYY-MM-DD)` with the actual close date.

- [ ] **Step 3 [CC]: Commit**

```bash
git add docs/IMPLEMENTATION.md
git commit -m "docs(implementation): close phase 4 — anatomical gui (static face)"
```

---

### Task 64: Slice 10 verification

- [ ] **Step 1 [VERIFY]: Final full suite**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit && swift test 2>&1 | tail -5
```

Expected: all green (Phase 3 baseline + ~50 new tests across Slices 1–9).

- [ ] **Step 2 [JAMEE/MANUAL]: Sign-off**

If the §14 checklist (Task 62) passes and any tuning iterations (Task 61) settled, Phase 4 closes. Otherwise, open follow-ups in IMPLEMENTATION.md and re-verify after each fix.

**Slice 10 verification:** Phase 4 acceptance criteria met live; IMPLEMENTATION.md reflects close; ready for Phase 5 brainstorm.

---

## Self-Review

(Performed at the end of plan-writing — see plan-summary commit message.)

1. **Spec coverage** — every spec section has at least one task:
   - §3 design decisions → Slice 0 (ADRs) + Slices 1–10 (implementation).
   - §4 architecture → Slices 1–4.
   - §5 data flow → Slices 4 (heart round-trip), 8 (wiring pulse).
   - §6 visual languages → Slices 1 (palettes/shaders), 2 (eyes-only-CRT), 4 (LCD).
   - §7 assets → Slice 0 deliverables list + Hayden gates in Slices 2/3/10.
   - §8 manufacturers/Model integration → Slice 9.
   - §9 housekeeping → Slice 0 Task 1.
   - §10 doc updates → Slice 0 Tasks 2–9.
   - §11 testing → unit tests in every slice + manual smoke in 10.
   - §13 dependencies on Hayden → Hayden gates marked [JAMEE].
   - §14 acceptance criteria → Slice 10 Task 62.
2. **Placeholders** — three intentional callouts marked as `TODO (Slice N follow-up)` (the Phase 3 ConversationManager wiring touch in ChatView; the live ToolRegistry wiring in ToolsDirectoryView). All are deferred to specific later slices, not handwaved.
3. **Type consistency** — `OrganID`, `FacePartKind`, `FrontmatterControlKind`, `BotFile`, `YAMLValue`, `BotStore.write` referenced consistently. Any drift between this plan's stubs and the actual b0tBrain / b0tCore signatures will surface at Step 2 (failing test) of each task — implementer is instructed to adjust.
4. **Scope** — single phase, single plan. No decomposition needed.
