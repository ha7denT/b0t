# b0t implementation amendment — 2026-05-04

**Status:** Active
**Supersedes:** prior decisions on parts ontology, Tools mechanism, naming, and unlock structure
**Scope of impact:** No GUI or face creator components have been built yet, so this amendment is largely additive. Existing non-GUI work (rig protocol, mood system, scene scaffolding) should be reviewed against the updated terminology but is unlikely to require deep refactoring.

## 1. Vocabulary — locked

The following terms are now canonical. All code, comments, manifest keys, file names, and user-facing strings should use these and only these:

- **Manufacturer** — an in-fiction firm that produces b0t units (e.g. fictional consumer-electronics, military, industrial brands). Manufacturers share a universe and visual substrate but have distinct identities.
- **Model** — a specific b0t unit produced by a Manufacturer. Each Model ships as a complete package (parts, palettes, decals, default Personality, default Modules, default Tools).
- **Part** — a structural component of the face rig. **Three part types only: Skull, Eyes, Jaw.** Ears are removed from scope.
- **Palette** — a curated colour scheme (4–5 named slots) applied to a Part variant at generation time. No runtime recolouring; palette variants are baked PNGs.
- **Decal** — surface markings applied over a Part (numbers, hazard stripes, manufacturer marks, stencils). **Formerly called "overlays" — rename throughout.** Decals are an independent rendering layer above Parts.
- **Module** — a directory of `.md` files providing domain knowledge the b0t can navigate (formerly under consideration as "Skills" — do not adopt that term). Users own Modules; b0t Models ship with defaults but Modules transfer across the user's gallery.
- **Tool** — an action the b0t can take (e.g. check calendar). User-owned; Models ship with defaults but Tools transfer across the gallery.
- **Personality** — a single `.md` file defining the b0t's voice and behaviour. **Formerly called "voice" — rename throughout.** Each b0t in the gallery has its own Personality.
- **Heartbeat** — the unlock currency, **per the Open Claw definition** (consult the existing Open Claw spec for accumulation rules). Only the active b0t accumulates heartbeats; only one b0t is active at a time.

Removed terms: **Ears, Accoutrements, Overlays, Voice, Skills.** Any references in existing code, ADRs, or docs should be migrated.

## 2. Architectural decisions — confirmed and amended

### 2.1 Parts system — three parts, not four

Drop Ears entirely from the rig, the manifest, the protocol, and the asset pipeline. The `FacePart` protocol now has three conformers: `SkullNode`, `EyesNode`, `JawNode`. The skull's `anchor_points` no longer needs `ear_left` or `ear_right` entries.

### 2.2 Asset generation — Gamelabs Studio, baked palette variants

Asset production uses Gamelabs Studio (gamelabstudio.co), not hand-authored Aseprite. The pipeline:

1. Reference art for a Part is uploaded to Gamelabs.
2. Gamelabs generates the Part at target resolution with palette injected into the prompt.
3. Each (Part variant × Palette) combination is generated separately and saved as a discrete PNG.
4. PNGs land in the appropriate `.spriteatlas` folder.
5. The manifest tracks which atlas frame corresponds to which (variant, palette) pair.

There is **no runtime palette swap shader.** The recolouring strategy is "bake all variants in the asset pipeline." This is a deliberate choice driven by (a) the curated-palettes-only design rule, (b) Gamelabs's strength at consistent multi-variant generation, and (c) the aesthetic preference for per-palette lighting that flat shader-tinting cannot deliver.

The manifest schema for Parts changes to:

```json
{
  "id": "domed",
  "category": "skull",
  "manufacturer": "<manufacturer_id>",
  "variants": [
    { "palette": "<palette_id>", "atlas_frame": "skull_domed_<palette>" }
  ],
  "anchor": [0.5, 0.5],
  "anchor_points": {
    "eyes_socket": [0.5, 0.55],
    "jaw_hinge":   [0.5, 0.25]
  },
  "gamelabs_prompt": "<saved prompt that produced these variants>"
}
```

Note the `gamelabs_prompt` field — every Part stores the prompt that produced it, so re-generation for new palettes is reproducible without prompt-archaeology.

### 2.3 Resolution hierarchy — formally locked

A diegetic three-tier hierarchy expressing "complexity built on fundamentals":

- **Face: 256px** — the b0t itself, where personality is expressed.
- **Organs: 64px** — capability units (Module organ, Tool organ, Memory bank, etc. per the system diagram).
- **Module icons: 16px** — Cobb-style semiotic markers identifying a Module. **Use a vocabulary of 12–24 base symbols** that compose into Module identifiers; do not allow per-Module bespoke icons.
- **Individual `.md` icons: 8px** — at this size, a single universal "file" icon is used. Distinction at the file level happens through filename, not iconography.

The 4× ratio between tiers is intentional and should be preserved. Asset generation prompts must specify these target resolutions so output is at native pixel count, not downscaled.

### 2.4 Manufacturers — origins, not silos

Parts from any unlocked Manufacturer can be combined freely once unlocked. Manufacturers are *origins* (where a Part came from) not *constraints* (what it can be used with). The "Frankenstein b0t" path is explicitly supported.

Visual cohesion across Manufacturers is enforced through three mechanisms — **all three are required, not optional**:

1. **Shared master palette substrate.** A 64-ish-colour master palette exists; each Manufacturer's named palettes draw from this set. No Manufacturer introduces colours outside the master.
2. **Shared silhouette grammar.** All Skulls share bounding-box rules. All Jaws hinge identically. All Eyes occupy compatible socket geometry. Encoded as constants in the rig code and validated by the manifest loader at build time.
3. **Shared weathering/grain treatment.** Common Gamelabs prompt fragments (texture, weathering language, grain intensity, lighting direction conventions) are baked into a *base prompt template* that every Manufacturer's prompts inherit from.

A `manufacturers.json` should be added to the catalog, with each Manufacturer entry containing its base prompt template, its palette set, and its identity description.

### 2.5 Tools — MCP is in scope for v1

The previous expectation that Tools would use MCP is **maintained**. The on-device LLM still needs a structured way to invoke actions, and MCP is a reasonable choice for that even on-device. If the implementation team determines a simpler mechanism is sufficient for v1 Tool needs, that's an engineering call — but Tools are *not* deferred from v1; they're part of the launch surface.

The previous brain-dump suggestion of "no MCP" was a misunderstanding of v1 scope; treat MCP as in-scope.

### 2.6 Marketplace — out of scope for v1, conceptually preserved

No marketplace ships with v1. The on-device experience is the entire product. However, the architecture should remain *marketplace-compatible* — meaning Modules, Tools, and Personality files should be structured as if a third party could one day publish them. Concretely:

- Modules are self-contained directories with no cross-Module dependencies.
- Tools have explicit interface contracts.
- Personality files declare which Manufacturer/Model they're styled for (metadata only, not enforced).
- Asset references in any of these are by stable ID, not by absolute path.

This is *forward-compatibility hygiene*, not active marketplace work.

## 3. Gallery and progression — new in this amendment

### 3.1 Gallery

Each user has a gallery of **up to 6 b0ts**. Each b0t is an independent unit with:

- Its own Model (defines parts, palette, decals, defaults)
- Its own customisation state (which Parts/Palettes/Decals the user has applied)
- Its own Personality file (initially the Model's default, user-editable)
- Its own active Modules
- Its own active Tools
- Its own conversation history and memory

**Only one b0t is active at any moment.** Switching b0ts is an explicit user action. The active b0t is the one currently in the foreground UI and the one accumulating heartbeats.

Memory does not transfer between b0ts. Modules and Tools, once unlocked, are user-owned and available to install on any b0t in the gallery.

### 3.2 Heartbeats and unlocking

Heartbeats accumulate **per Open Claw's existing definition**. The implementation team should consult the Open Claw spec for accumulation rules; do not invent new rules.

Each Model has a single heartbeat threshold. When the active b0t crosses that threshold, the **entire content package for the next Model** unlocks simultaneously: Parts, Palettes, Decals, default Personality, default Modules, default Tools.

The user can **see** future upgrades in the catalogue (preview state), but cannot interact with them until unlocked. This gives anticipation without false agency.

### 3.3 Pre-built vs. build-your-own

On Model unlock, the user is offered two paths:

- **Pre-built** — start with the Model's default configuration. Lower friction; recommended for most users.
- **Build-your-own** — open the face creator with all unlocked Parts/Palettes/Decals available.

Both paths produce the same kind of b0t in the gallery. The choice is onboarding flow, not a permanent state.

## 4. Naming and migration tasks

When the implementation team picks up this amendment, the following renames must be performed in one pass:

- `voice.md` → `personality.md` (and any code references)
- `Overlay`/`OverlayNode` → `Decal`/`DecalNode` (and any code references)
- Remove all `Ear`/`EarsNode` references from the rig, manifest schema, and asset pipeline
- Confirm "Skill" is not used in user-facing strings; "Module" is the canonical term
- Confirm "Accoutrement" is not used anywhere

A grep pass for the removed terms (Ears, Voice, Overlay, Accoutrement, Skill) is sufficient to surface migration work.

## 5. Open questions deferred to implementation

These are intentionally not decided here and should be raised by the implementation team at the appropriate moment:

- The exact Module icon vocabulary (12–24 symbols) — design exercise, will be supplied separately.
- The default starter Modules shipped with the v1 launch Manufacturer — content task.
- The specific Manufacturers in the v1 launch lineup and their visual identities — design task.
- Heartbeat threshold values per Model — balancing task, defer until at least one Model is fully implemented and playable.
- Anchor point coordinates for each Part variant — emerge from the art, not decided in advance.

## 6. What this amendment does not change

- ADR 0003 (SpriteKit + SwiftUI over Rive) stands.
- The aesthetic doctrine in `aesthetic-references.md` stands. All amendments above must remain consistent with it. In particular: the "would the in-fiction firm have issued this?" test now applies *per Manufacturer*, sharpening rather than weakening the rule.
- The mood system (~8 mood states per Part) stands.
- The motion vocabulary library approach stands.
- The manifest-driven, agent-editable architecture stands.
