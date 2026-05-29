# 0008 — Implementation amendment — 2026-05-04 vocabulary and architectural locks

**Status:** Partially superseded by [0012](0012-inference-engine-agnostic.md) and [0013](0013-v1-single-non-modular-bot.md) — for **v1**, the Gamelabs baked-palette pipeline, the gallery (cap 6), heartbeat-unlock currency, and Manufacturers-as-content defer to v2. This amendment is **retained as the v2 design.** The vocabulary lock, three-Part ontology, MCP-for-Tools, and marketplace-compatible architecture still stand.
**Date:** 2026-05-04
**Deciders:** Jamee
**Supersedes:** prior decisions on parts ontology, Tools mechanism, vocabulary, and unlock structure where they conflict with this amendment.

## Context

Phase 2 (Foundation Models loop) closed on 2026-05-04. Before brainstorming Phases 3–7 — modules, tools, anatomical GUI, face creator, gallery, and unlock — the design space needed to settle. Open vocabulary choices and branching architectural options would have produced inconsistent specs across phases. This amendment locks them in a single document so every subsequent phase inherits a stable substrate.

## Decisions

### Vocabulary lock

The canonical terms for b0t's domain are:

**Accepted:** Manufacturer, Model, Part, Palette, Decal, Module, Tool, Heartbeat.

**Rejected:** Ears (as a Part), Accoutrement, Overlay (as a face-composition concept), Voice (as a b0t Identity concept), Skill (superseded by Module in commit `643b6f3`).

ADR-0005's three-file Identity (`core.md` / `principles.md` / `about_b0t.md`) stands. The "Personality" concept surfaced during amendment discussions was declined — Identity remains the correct term and the existing split is preserved as-is.

### Parts: three only (Skull / Eyes / Jaw)

The face rig has exactly three Part slots: **Skull**, **Eyes**, **Jaw**. Ears were proposed and rejected. Ears are removed from the rig, manifest schema, pipeline, and all specs. No fourth Part slot.

### Asset pipeline: Gamelabs Studio with baked palette variants

Assets are produced via **Gamelabs Studio** (gamelabstudio.co). Each Part × Palette combination is a pre-baked PNG. There is no runtime palette-swap shader. The manifest stores a `gamelabs_prompt` field per Part for reproducibility. Phase 4 and Phase 6 specs must not design for runtime recolouring.

### Resolution hierarchy

Four tiers, 4× ratio between each:

| Tier | Resolution | Content |
|---|---|---|
| Face | 256 px | Full face composites |
| Organs | 64 px | Part sprites in the anatomical GUI |
| Module icons | 16 px | Module organ icons |
| `.md` icons | 8 px | Inline markdown file icons |

### Manufacturers: origins, not silos

Manufacturers are the in-fiction firms that produce Parts. Cross-manufacturer mixing is allowed once unlocked. Cohesion across Manufacturers is maintained by: a shared 64-colour master palette substrate, a shared silhouette grammar, and a shared weathering/grain treatment. The "would the in-fiction firm have issued this?" test applies per Manufacturer.

### Tools mechanism: MCP in scope for v1

MCP is in scope for Tools in v1. Phase 3 spec must account for this.

### Marketplace: out of scope for v1, architecture stays compatible

An online module marketplace is out of scope for v1. However, the architecture must remain marketplace-compatible: Modules are self-contained, Tool interface contracts are explicit, and all asset references are ID-based.

### Gallery: up to 6 b0ts, single-active

The gallery holds up to 6 b0ts. Only one b0t is active at any time. Memory does not transfer between b0ts. Modules and Tools transfer once user-unlocked. PRD §2 #8 updated: soft-cap is 6 (was 5).

### Heartbeat-unlock currency

Heartbeats are the unlock currency for Models and cross-manufacturer access. Each Model has a single heartbeat threshold. When the threshold is crossed, the entire next Model's content package unlocks atomically. At unlock, two onboarding paths are offered: pre-built (accept the new Model as-is) and build-your-own (compose from available Parts).

## Consequences

- **Skills → Modules rename** executed in commit `643b6f3`. Mechanical, surface-only.
- **Phase 3** retitled "Module bridges + Tools" (was "Skill bridges").
- **Phase 4** spec must hold: 3 Parts (Skull/Eyes/Jaw), 256/64/16/8 resolution tiers, baked palette variants, Manufacturer system as origins not silos.
- **Phase 6** (Face Creator) inherits the manifest schema with `gamelabs_prompt`, and the `manufacturers.json` cohesion catalog.
- **Phase 7** (Multi-b0t + Gallery) implements the gallery cap of 6 and heartbeat-currency unlock flow.
- **`default-bot/identity/appearance.md`** updated: `overlays`/`accoutrements` frontmatter keys renamed to `decals`; content aligned to current vocabulary.
- **`docs/design_document.md` §2.5 and §10** updated: Face Creator described as "parts + decals" (Accoutrements removed from scope; Overlays renamed to Decals).
- **`docs/prd.md` Phase 6 and §2 #10** updated to match.

## What this amendment does not change

- **ADR-0003** (SpriteKit + SwiftUI over Rive) stands.
- **ADR-0005** (three-file Identity split) stands. Personality concept declined.
- **`docs/references/aesthetic-references.md`** stands. The "would the in-fiction firm have issued this?" test now applies per Manufacturer, not just for the default b0t.
- **8 mood states per Part** (idle, speaking, thinking, surprised, sleepy, attentive, worried, delighted) stands.
- **Motion vocabulary library approach** stands.
- **Manifest-driven, Claude-Code-editable architecture** stands.
