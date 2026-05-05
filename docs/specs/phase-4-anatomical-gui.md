# Phase 4 — Anatomical GUI (static face)

**Status:** Settled, ready for plan-writing
**Brainstormed:** 2026-05-05
**Supersedes:** `docs/specs/phase-4-assets-checklist.md` (delete on merge)
**Depends on:** ADR-0003, ADR-0007, [2026-05-04 amendment](../b0t-amendment-2026-05-04.md), [aesthetic-references.md](../references/aesthetic-references.md), [voice-and-copy-guide.md](../references/voice-and-copy-guide.md)
**Produces:** ADR-0010, ADR-0011, this spec, `docs/references/face-roster.md`, `b0tApp/Resources/manufacturers.json`

## 1. Overview

Phase 4 ships the home screen — the b0t alive on glass. One static face (Hilfer, the Wundercog tier-1 starter Model) composed from three baked Parts, surrounded by a 9-organ ring with a beating heart and pulsing wiring, sitting on top of a backlit-LCD inspection panel that doubles as the chat surface. The face does not yet animate; mood states, blink loops, and breathing all defer to Phase 6 alongside the Face Creator. Everything else around the face is alive.

The phase is a **visual-design probe with full interaction**: the cassette-futurism look gets validated on glass, chat works, every organ is tappable, every file is editable. The deferred rig is purely a content drop later — the architecture exercises its eventual home from day one.

## 2. Scope

### In scope

- Anatomy view, top half: Hilfer composed of three baked Parts (Skull / Eye-screen / Jaw) at 256px native, layered correctly, with the Eye-screen carrying the only CRT scanline overlay in the system. Decal layer pre-wired (no Hilfer assets).
- Organ ring: 9 organs at 64px in the locked layout — Reasoning at the crown, Memory and Modules upper, Identity left, Tools / Sensors / Location / Network below, Heart distinguished bottom-centre.
- Live procedural visuals: heart pulse driven by `heartbeat/schedule.md` BPM, wiring pulses direction-aware on tool/memory access, organ-activity glow when an organ is being read or written.
- LCD inspection panel, bottom half: backlit warm-amber LCD treatment (calculator / OP-1 / Tandy Model 100 sensibility — no bloom, no scanlines, fixed-grid for system labels, Verdana for chat content). Default state shows the chat scrollback and composer. Tapping any organ swaps the panel to that organ's controls.
- Frontmatter-as-controls renderer: any `.md` file's frontmatter renders as native SwiftUI controls inline with the prose. Two-tier dispatch — type fallback plus a small semantic registry for known keys (bpm, quiet_hours, enabled, verbosity).
- Edit mode: full-screen markdown editor reachable from any inspection view.
- `manufacturers.json` runtime catalogue with the Wundercog Manufacturer entry and the Hilfer Model entry. `BotProvisioner` on first launch reads Hilfer's defaults from this file.

### Out of scope (deferred)

| Item | Goes to |
|---|---|
| Face rig — 8 mood states per Part, blink loop, breathing, mouth-open cycle | Phase 6 |
| Decal **assets** for Hilfer (the layer ships in Phase 4; no decal PNGs) | Phase 6 / later content drops |
| Other 14 Models in the roster (parts, palettes, decals) | Phase 6+ as Models unlock |
| Progression / unlock / heartbeat-thresholds (Open Claw spec) | own brainstorm session, then Phase 7 + Phase 9 |
| Multi-bot gallery, importing Modules / Tools / Personality across b0ts | Phase 7 |
| Master 64-colour palette + cross-Manufacturer cohesion infrastructure | Phase 6 (when 2nd Manufacturer ships) |
| TTS, audio filters, UI sounds | Phase 8 |
| Mood-variant notification icons | Phase 6 |
| Procedural-animation guidance for the rig | own session as `docs/specs/face-creator-procedural-animation.md` |

## 3. Design decisions — settled in brainstorming

1. **Phase 4 = full anatomical GUI with one static face.** Not a visual-only probe, not a 4a/4b split. Chat composer, organ-tap inspection, full-screen edit mode all ship. The rig defers; everything else is in.
2. **Animation scope: defer the face rig only.** Heart pulse, wiring pulses, organ-activity pulses ship in Phase 4 — they are not the rig. The rig is the SpriteKit mood-state machine over Part atlases (Phase 6).
3. **Hilfer is the static face.** Wundercog tier-1 starter / onboarding Model. Composed from three baked Parts.
4. **9-organ ring layout, asymmetric.** 4 organs above the eye-line (Reasoning at the crown; Memory, Modules, Identity arranged around), 4 below (Tools, Sensors, Location, Network), Heart distinguished at the bottom-centre. The asymmetry on the right side of the upper ring is accepted, not balanced with a fifth slot.
5. **Inspection pattern: tap any organ → LCD swap.** The LCD inspection panel takes the area below the anatomy. Frontmatter renders as native controls inline with markdown content. Some organs (Modules, Tools, Memory, Identity) surface a directory of `.md` files to navigate. Default LCD state when nothing is selected = chat.
6. **Render path: SpriteKit-first hybrid (Approach 2).** A `SpriteView` containing one `SKScene` for the anatomy, with a SwiftUI inspection panel below. The Phase 4 face is one composed-but-static `FaceComposite`; Phase 6 swaps in atlases and a mood-state machine without rewriting the rendering plumbing.
7. **Visual languages, distinct.** The Eye-screen is the only CRT surface in the system (phosphor + subtle scanline shader). Skull, Jaw, organs, heart are flat pixel art with painterly lighting. Wiring is procedural — `SKShapeNode` lines with phosphor-glow tint, code-drawn rather than rastered. The LCD inspection panel is backlit warm-amber — calculator / OP-1 sensibility, no bloom, no scanlines.
8. **Type:** IoskeleyMono NL for system / brain labels (pixel-grid coherent). **Verdana for chat content** (humanist sans, readable inside the LCD chrome, system-provided on iOS — no licensing concern).
9. **Asset pipeline: Gamelabs Studio, baked PNGs.** No runtime palette swap. Each `(Part variant × Palette)` combination is generated, baked, and dropped in a sprite atlas. Each Part stores its `gamelabs_prompt` in the manifest for reproducibility (per amendment §2.2).

## 4. Architecture

### 4.1 Module layout

| Module | Role | Phase 4 additions |
|---|---|---|
| `b0tKit/Sources/b0tDesign` | Design tokens — palettes, colour roles, LCD/CRT shader code, type aliases | Wundercog palette tokens, LCD palette tokens, CRT scanline `SKShader`, type aliases for IoskeleyMono and Verdana |
| `b0tKit/Sources/b0tFace` | Anatomy rendering — `FacePart` protocol, Part nodes, scene tree | `SkullNode`, `EyesNode`, `JawNode`, `DecalNode`, `FaceComposite`, `AnatomyScene`, `OrganNode`, `HeartNode`, `WiringNetwork` |
| `b0tKit/Sources/b0tHome` *(new)* | Home-screen view layer — SwiftUI shell, LCD panel, inspection, chat, editor | `HomeView`, `InspectionPanel`, `ChatView`, `OrganInspectionView`, `DirectoryNavigatorView`, `EditorView`, `FrontmatterControl` renderers, `AnatomyState` |
| `b0tApp/Sources/App/ContentView.swift` | Thin iOS shell | Becomes a one-liner that hosts `b0tHome.HomeView`. The existing `DebugBrainView` stays as a debug-only sheet behind a long-press or hidden affordance. |

`b0tHome` depends on `b0tFace`, `b0tDesign`, `b0tBrain`, and `b0tCore`. Putting view code in `b0tKit` keeps it testable and `RenderPreview`-able.

### 4.2 View hierarchy

```
HomeView (SwiftUI, b0tHome)
├── AnatomyView (SwiftUI, b0tFace)
│   └── SpriteView
│       └── AnatomyScene : SKScene
│           ├── FaceComposite : SKNode               (positioned by Skull anchors)
│           │   ├── EyesNode    : SKEffectNode       (scanline shader, child SKSpriteNode)
│           │   ├── SkullNode   : SKSpriteNode
│           │   ├── JawNode     : SKSpriteNode       (anchored at Skull.jaw_hinge)
│           │   └── DecalNode   : SKNode             (empty for Hilfer)
│           ├── HeartNode      : SKNode              (BPM-driven pulse)
│           ├── WiringNetwork  : SKNode              (per-organ SKShapeNode lines)
│           └── OrganNode × 9                        (64px sprite + ActivityPulse subnode)
├── InspectionPanel (SwiftUI, b0tHome)               (LCD treatment — backlit warm amber)
│   ├── ChatView                          (default — no organ selected)
│   ├── OrganInspectionView               (organ selected)
│   │   ├── MarkdownRenderer
│   │   └── FrontmatterControls
│   └── DirectoryNavigatorView            (Modules / Tools / Memory / Identity)
└── (modally) EditorView                  (full-screen markdown editor)
```

### 4.3 `AnatomyState` — the SpriteKit/SwiftUI bridge

A single `@Observable` source of truth in `b0tHome` connects scene events to view updates and back:

```swift
@Observable
public final class AnatomyState {
    public var selectedOrgan: OrganID?
    public var activeWiring: Set<OrganID>
    public var heartBPM: Int
    public var bot: Bot
    public var store: BotStore
    // ...
}
```

- **Scene → state** (touch events): `AnatomyScene.touchesBegan` does node-name hit-testing on the topmost interactive node and writes `state.selectedOrgan`. SwiftUI re-renders `InspectionPanel` to match.
- **State → scene** (animation triggers): the scene observes `state` (stored reference, wired up in `didMove(to:)`). Mutations to `activeWiring`, `heartBPM`, etc. trigger the corresponding scene-level animations.
- **External signal sources** also write to `state`: `HeartbeatManager` and the tool executor (existing in `b0tCore`) publish events that translate into transient `activeWiring` membership.

### 4.4 Hit-testing rule

- **Anatomy taps** are owned by SpriteKit. The scene reads `node.name` (a stable `OrganID` rawValue) via `nodes(at:)`. SwiftUI does *not* attach `.onTapGesture` to the `SpriteView` — that fights the scene.
- **LCD panel taps** are owned by SwiftUI. Standard gesture modifiers throughout. Anatomy and LCD never overlap in the layout, so no collision.
- **Dismiss inspection → back to chat:** an explicit "back" affordance in the top-left of the inspection view, plus tapping the same organ a second time = deselect.

### 4.5 LCD inspection panel — content by organ

| selectedOrgan | Renders |
|---|---|
| `nil` | `ChatView` — scrollback + composer, fed by the existing `ConversationManager` |
| `.heart` | `OrganInspectionView` over `heartbeat/schedule.md` — BPM slider + quiet-hours range picker inline |
| `.modules` | `DirectoryNavigatorView` over `modules/`. Tap a module → `OrganInspectionView` for that module's `.md` |
| `.tools` | `DirectoryNavigatorView` over a virtual directory built from `ToolRegistry` — each tool gets a pseudo-file view |
| `.memory` | `DirectoryNavigatorView` over `memory/` |
| `.identity` | `DirectoryNavigatorView` over `identity/` (the personality surface — `core.md`, `principles.md`, `audio.md`, `appearance.md`, `about_b0t.md`). The `identity/` directory IS the personality file per Phase 4 brainstorm |
| `.reasoning` | `OrganInspectionView` over a synthesised "reasoning state" file — read-only: last decision, last tokens-in/out, current model session age. No editable params yet |
| `.sensors` | `OrganInspectionView` over a synthesised "sensors state" file — text-input toggle and a link to `identity/audio.md` if STT-related settings live there. Phase 4 ships the read surface; sensor-specific configuration files come later if needed. |
| `.location` | `OrganInspectionView` over a synthesised location-state file — read-only "no location module shipped yet" placeholder. The organ exists architecturally; the module ships later |
| `.network` | `OrganInspectionView` over a synthesised network-state file — read-only "no network access in v1." Same architecture-without-module pattern |

### 4.6 Frontmatter-as-controls — the pattern

`OrganInspectionView` reads the underlying `BotFile`, splits frontmatter from prose, and renders:

- **Prose:** existing markdown rendering. `Text(.init(markdown:))` is sufficient for v1.
- **Frontmatter:** each key dispatches to a `FrontmatterControl` view via two-tier lookup:
  1. **Type-based fallback** — `Bool` → `Toggle`; `Int` → `Stepper`; `ClockTime` → `DatePicker(.hourAndMinute)`; `ClockRange` → range picker; `String` → `TextField`; enum-shaped string → segmented `Picker`.
  2. **Semantic registry** — small dictionary of well-known keys with specialised renderings: `bpm` → `Slider(1...12, step: 1)` with "♡ N bpm" label; `quiet_hours` → custom `ClockRange` picker with overnight-range support; `enabled` → `Toggle` with module-name label. The registry is the *only* place range / step / label specialisation lives — no in-file annotation conventions.

Two-way binding: `@Bindable` reads through `bot.file(at:)`, mutations route through `BotStore.write` debounced ~300ms so a slider drag doesn't fsync 50 files per second.

The pattern generalises: any new module's `.md` with parameter-shaped frontmatter automatically gets a usable inspection UI without per-organ custom code.

## 5. Data flow

**Heart BPM round-trip:**

```
user drags slider in OrganInspectionView (heart)
  → @Bindable write to AnatomyState.heartBPM
  → BotStore.write to heartbeat/schedule.md (debounced)
  → file mutation
  → AnatomyScene observes AnatomyState.heartBPM change
  → HeartNode cancels old SKAction.repeatForever, starts new at new tempo
  → next HeartbeatManager.scheduleNext() reads the new BPM from disk
```

**Calendar tool invoked → wiring pulse:**

```
ConversationManager invokes calendar.upcoming_events
  → tool executor publishes ToolInvocation event
  → AnatomyState.activeWiring inserts(.calendar) for ~2s
  → AnatomyScene plays direction-aware pulse on the calendar organ's wiring
    (face → organ for outgoing, organ → face for incoming response)
  → also pulses the Tools organ (calendar is accessed via Tools)
  → after 2s, AnatomyState removes the entry, scene dims wiring back
```

**User taps Memory organ:**

```
SpriteKit hit-test → "memory" node name
  → AnatomyState.selectedOrgan = .memory
  → InspectionPanel re-renders as DirectoryNavigatorView over memory/
  → user taps a file → drill into OrganInspectionView for that file
  → user taps "edit" → EditorView modal full-screen
  → user edits, saves → BotStore.write → returns to inspection view
```

## 6. Visual languages

| Surface | Treatment | Implementation |
|---|---|---|
| Eye-screen | CRT phosphor + subtle scanline overlay | `SKEffectNode` wrapping the eye-screen `SKSpriteNode`, fragment shader (`SKShader`) for scanlines. The only CRT surface in the system. |
| Skull / Jaw / organs / heart | Flat pixel art with painterly lighting | `SKSpriteNode`, nearest-neighbour filtering, no shader chrome. Replaced / Kingdom Two Crowns sensibility per `aesthetic-references.md`. |
| Wiring | Phosphor-glow lines with direction-aware pulse | `SKShapeNode` with line strokes; pulses run an `SKAction.colorize` + glow tween. Per `aesthetic-references.md`: warm phosphor — amber, green, cream. Never blue. |
| Inspection / chat panel | Backlit warm-amber LCD | SwiftUI: warm dark gradient background, amber text, thin chrome border. No bloom, no scanlines, no glow. Calculator / OP-1 / Tandy Model 100. |

### 6.1 Type

- **IoskeleyMono NL** (`assets/fonts/IoskeleyMono-NL/`) — system / UI / brain labels (organ titles, status indicators, frontmatter labels, monospaced everywhere except chat content).
- **Verdana** — chat content inside the LCD. System-provided on iOS, no licensing concern. Humanist sans-serif, large x-height, designed for screen readability — sits cleanly inside the LCD chrome without fighting the pixel-art surrounding it.

### 6.2 Palette (Phase 4 — Wundercog Hilfer only)

Defined as named colour roles in `b0tDesign`:

- `WundercogPalette.shellOffwhite` — Hilfer's polymer skull and jaw shell.
- `WundercogPalette.accentMint` — eye glow, jaw underline, bezel highlight.
- `WundercogPalette.bezelMintThin` — single-pixel mint bezel around the eye-screen cutout.
- `WundercogPalette.eyePhosphor` — the phosphor-glow tint inside the eye-screen.
- `WundercogPalette.seamDark` — subtle panel-seam shadowing.

LCD palette:

- `LCDPalette.bgWarm` — warm dark grey-amber backlight.
- `LCDPalette.textAmber` — primary amber text.
- `LCDPalette.textDim` — secondary text (50% opacity equivalent in design).
- `LCDPalette.chromeDark` — bezel border around the LCD area.

The full master 64-colour palette per amendment §2.4 is forward-looking; Phase 4 ships only what Hilfer needs.

## 7. Asset deliverables

### 7.1 Hilfer's three Parts (Gamelabs)

| Asset | Resolution | Source |
|---|---|---|
| Hilfer Skull (idle, off-white polymer + mint-green bezel) | 256px | Gamelabs prompt + Wundercog base template |
| Hilfer Eye-screen (idle, mint-green eyes) | 256px | Gamelabs |
| Hilfer Jaw (idle, off-white polymer + mint-green underline) | 256px | Gamelabs |

The three Hilfer prompts live in `face-roster.md` under `Wundercog/Hilfer`. Each Part's manifest entry stores its `gamelabs_prompt` per amendment §2.2.

### 7.2 Organ icons

- 9 organ icons at **64px native** (idle state only). Activity-pulse is procedural — `SKAction.colorize` + intensity tween over the idle sprite. No separate "active" PNG.
- 4 module sub-icons at **16px** for Phase 3's shipped modules (calendar, reminders, time-awareness, health). The 12–24-symbol module-icon vocabulary called for by amendment §2.3 isn't defined yet (open question, deferred to a separate design exercise per amendment §5). Phase 4 ships **interim bespoke icons** for the four shipped modules, with the explicit understanding that they will be redrawn from the eventual vocabulary in a later content drop. Flagged in `IMPLEMENTATION.md` notes when the phase closes.
- 1 universal file icon at **8px** for `.md` rows in `DirectoryNavigatorView`.

### 7.3 Code-drawn (no PNG)

- Wiring lines (`SKShapeNode` line strips with phosphor-glow tint and direction-aware pulse animations).
- Heart pulse: 1 PNG of the heart shape at 64px (counted in the 9 organ icons above), scale-pulsed at `heartBPM` interval via `SKAction.repeatForever`. No separate "pulse" frame.
- LCD chrome (SwiftUI gradients + borders).
- CRT scanline shader on the Eye-screen (`SKShader`, fragment).

## 8. Manufacturer / Model integration

### 8.1 `b0tApp/Resources/manufacturers.json` — Phase 4 shape

```json
{
  "manufacturers": [
    {
      "id": "wundercog",
      "name": "Wundercog Industries",
      "base_prompt_template": "Pixel art at 256×256, forward-facing portrait, pure black background, head and jaw only, no neck or body, …matte off-white polymer shell, soft bulbous forms, no sharp edges, friendly utility aesthetic. Universal interchange: standard rectangular eye-panel underneath the cutout, jaw mounts to standard hinge point, jaw seam positioned just above mouth-line so the upper lip-equivalent is part of the jaw module, skull occludes jaw sides and houses the speaker behind the jaw plane.",
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

`BotProvisioner` on first launch reads Hilfer's defaults from this file and initialises `default-bot/` accordingly. The Phase 3 `BotProvisioner` staleness follow-up (only copies on first launch) is *not* fixed in Phase 4 — flagged as an open follow-up; existing simulator installs may need a wipe.

### 8.2 `docs/references/face-roster.md`

Single human-readable document organised by Manufacturer → Model. Each Manufacturer gets its base prompt template, shared-palette notes, and identity description. Each Model under a Manufacturer gets the full Gamelabs prompt (skull, eye-screen, jaw, palette), tier (1/2/3 within manufacturer), and notes on its role in the fiction.

All five Manufacturers × three Models = 15 Models captured for prompt provenance, including the kc-oracle palette correction (`bare aluminum, brushed titanium accents, magenta anodized accents, magenta coolant glow`). Only Wundercog/Hilfer's prompts get fed into Gamelabs for Phase 4; the rest sit as reference.

## 9. Pre-Phase-4 housekeeping

A small commit, single PR, that lands *before* Phase 4 implementation begins. Per amendment §4 minus the voice→personality skip:

- Remove any `Ear*` references in code, manifest schemas, asset pipeline (likely zero today since `b0tFace` is a placeholder; verify with `grep -r 'Ear' --include='*.swift'`).
- Rename `Overlay` / `OverlayNode` → `Decal` / `DecalNode` everywhere.
- Confirm `Skill` is not used in user-facing strings (`Module` is canonical).
- Confirm `Accoutrement` is not used anywhere.
- PRD / design doc terminology pass for any lingering old terms.
- **Skipped:** `voice.md` → `personality.md`. The `default-bot/identity/` directory IS the personality surface; no separate file needed. The Identity organ surfaces this directory.

## 10. Doc & ADR updates

Land in this order, typically across two PRs (the housekeeping PR first, then the Phase 4 spec PR):

**Housekeeping PR:** §9 above.

**Phase 4 spec PR:**

1. `docs/decisions/0010-organs-are-anatomical-subsystems.md` — supersedes the "organs = modules" framing in ADR-0007. Records the nine fixed organs. The Modules organ is the meta-organ surfacing module `.md` files; the Tools organ surfaces individual tool icons. The 10 modules in design doc §4.2 still ship — they live *inside* the Modules organ.
2. `docs/decisions/0011-defer-face-rig-to-phase-6.md` — records the Phase 4 art pivot (single static face composed of three Parts, no animation). Phase 6 absorbs rig + Face Creator + parts library together. Cross-references the 2026-05-04 amendment for the Manufacturer/Model/Part vocabulary.
3. `docs/specs/phase-4-anatomical-gui.md` — this file.
4. `docs/references/face-roster.md`.
5. `b0tApp/Resources/manufacturers.json`.
6. **PRD edits** (targeted): §3 Phase 4 acceptance updated; §3 Phase 6 absorbs rig + parts + Face Creator; §5.4 prefaced with "rig ships in Phase 6"; §12 Q4 closed (asset pipeline is Gamelabs).
7. **Design doc edits** (targeted): §3.3 organ language updated (organs = anatomical subsystems); §4.2 reframed (modules live *inside* the Modules organ).
8. `docs/specs/phase-4-assets-checklist.md` deleted (superseded by §7 of this spec).
9. `docs/IMPLEMENTATION.md` — Phase 4 status flips to "specced," ledger entry, Specs-in-flight updated.

## 11. Testing strategy

| Layer | Test | Confidence |
|---|---|---|
| `BotFile` parse / write | Existing unit tests (Phase 1) | high |
| `FrontmatterControl` type dispatch + semantic registry | New unit tests in `b0tHome` against `BotFile` fixtures (heart bpm slider, quiet_hours range, module-enabled toggle) | high |
| `AnatomyState` transitions (`selectedOrgan`, `activeWiring`, `heartBPM`) | New unit tests, no SpriteKit involved | high |
| `AnatomyScene` node tree (child ordering, anchor-driven positions) | New unit tests against the scene's pre-`didMove` state — assertions on `nodes(at:)`, `anchorPoint`, `name` | medium |
| Heart BPM round-trip — slider → file → scene tween restart | Integration test: build the scene, mutate state, assert the `repeatForever` action's interval | medium |
| Wiring pulse on tool invocation | Integration test: publish `ToolInvocation`, assert scene's wiring node received the pulse action | medium |
| `HomeView` snapshots — idle (chat default), each organ inspection mode, edit mode | Snapshot tests via `swift-snapshot-testing` (chosen at slice 4) or Apple's built-in snapshots | medium |
| Visual fidelity | `RenderPreview` (Apple Xcode MCP) for each view at design time | medium — visual judgement remains Jamee's |
| End-to-end smoke (live anatomy on simulator, organ taps swap LCD content, heart beats at BPM, calendar tool pulses wiring) | Manual on-simulator smoke per Phase 3 pattern, documented in `IMPLEMENTATION.md` notes | acceptance gate |

Phase 3 lessons applied:

- **No fakes that ignore inputs.** The frontmatter-control test harness round-trips through actual `BotFile` writes, not a mock — otherwise we'd repeat the `FakeEventKitStore`-ignores-predicate bug.
- **Audit every constructor call site when adding a parameter.** `HomeView(bot:store:anatomyState:)` lands in both `b0tApp/ContentView` and any preview / test entry; all updated atomically per Phase 3 lesson #1.

## 12. Performance notes

- `SKAction.repeatForever` for heart pulse is GPU-cheap. Same for organ activity flickers.
- Wiring `SKShapeNode`s use line-strip primitives — fine at 9-organ count. If line count grows, batch into a single `SKShapeNode` per network direction.
- Backlit-LCD treatment is pure SwiftUI gradient + opacity — ~zero cost.
- Scene is mostly idle (one heartbeat tween + occasional wiring pulse). 60fps target on iPhone 14 Pro per ADR-0007 is comfortably met.
- Foundation Models session is short-lived per ADR-0008; no concurrent FM session during scene rendering except during a chat reply, where it's already known to coexist with UI per Phase 2.

## 13. Dependencies on Jamee

Called out so they don't surface mid-build:

1. **Hilfer's three Part PNGs** at 256px (Skull, Eye-screen, Jaw) — Jamee delivers from Gamelabs. *Jamee committed in brainstorming: "I will provide the 3× PNGs."*
2. **9 organ icons** at 64px — Jamee delivers.
3. **4 module sub-icons** at 16px (calendar, reminders, time-awareness, health) plus the universal 8px file icon — Jamee delivers.
4. **Verdana for chat** — system-provided on iOS; no asset to deliver, no licensing concern.

Implementation can scaffold against placeholder squares for assets 1–3, but the visual-design probe doesn't validate until the real PNGs are in place.

## 14. Acceptance criteria

Phase 4 closes when, on a real-device or simulator-with-Apple-Intelligence smoke pass driven by Jamee:

1. App opens to the home screen showing Hilfer composed of three Parts (Skull / Eye-screen / Jaw), with the Eye-screen carrying the CRT scanline overlay.
2. The 9-organ ring is laid out per the locked layout, each organ icon visible.
3. The heart at the bottom pulses at the BPM declared in `heartbeat/schedule.md`.
4. Wiring lights up and pulses direction-aware when a tool is invoked.
5. Tapping any organ swaps the LCD inspection panel to that organ's controls.
6. Frontmatter renders as native controls in the inspection view (verified against the heart organ at minimum: BPM slider; verified against one module organ for `enabled:` toggle).
7. Sliding the BPM slider mutates `heartbeat/schedule.md` on disk and the heart node's pulse rate updates within a few seconds.
8. Tapping "edit" from any inspection view opens a full-screen markdown editor; saving writes back; cancelling discards.
9. With no organ selected, the LCD shows the chat scrollback and composer; sending a message routes through the existing `ConversationManager` and the b0t replies in voice.
10. The visual languages stay distinct: only the Eye-screen has CRT scanlines; the LCD has no bloom, no scanlines.

Each criterion is verified live by Jamee per the Phase 3 smoke pattern. The agent harness can't drive simulator UI deterministically.

## 15. Forward-looking, *not* this spec's output

- Procedural-animation guidance for the Phase 6 face rig — own session, output `docs/specs/face-creator-procedural-animation.md`.
- Progression / unlock / heartbeat-thresholds — own brainstorm session before Phase 7.
- Master 64-colour palette + cross-Manufacturer cohesion infrastructure — Phase 6 (when 2nd Manufacturer ships).
- `BotProvisioner` "sync new files from bundle on launch" — Phase 3 follow-up; Phase 4 does not address it.

## 16. References

- ADR-0003 — SpriteKit + SwiftUI over Rive
- ADR-0007 — Anatomical GUI as the primary interface, not chat
- ADR-0008 — Implementation amendment 2026-05-04
- ADR-0009 — Module protocol simplification
- ADR-0010 — Organs are anatomical subsystems *(this spec produces)*
- ADR-0011 — Defer face rig to Phase 6 *(this spec produces)*
- [b0t implementation amendment — 2026-05-04](../b0t-amendment-2026-05-04.md)
- [aesthetic-references.md](../references/aesthetic-references.md)
- [voice-and-copy-guide.md](../references/voice-and-copy-guide.md)
- [face-roster.md](../references/face-roster.md) *(this spec produces)*
