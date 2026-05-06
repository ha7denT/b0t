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
