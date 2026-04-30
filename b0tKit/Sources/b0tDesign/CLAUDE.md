# b0tDesign

Design tokens, palettes, fonts, and shared SwiftUI views.

## Public API contracts (target shape)

- `Palette` — 12 curated palettes (no RGB picker — see PRD non-negotiable #9).
- `Token` namespace — colours, spacings, type ramps.
- `Font` — IoskeleyMono NL (brain layer) and Söhne (chat).
- Shared views: `OrganLabel`, `StatusGlow`, `PhosphorWire`, etc. (added as Phase 4 lands).

## Patterns

- **Warm darks, never pure black.** Phosphor glows are amber/green/cream, never blue. See design doc §3.5.
- All colour goes through palette slots: `primary`, `accent`, `shadow`, `highlight`. Never raw hex outside this module.
- All-lowercase for system labels. Sentence-case for the b0t's voice. Never title-case.

## Read first when working here

- `docs/design_document.md` §3 (the entire aesthetic section)
- `docs/references/voice-and-copy-guide.md`
- `assets/palettes/`, `assets/fonts/`
