---
mutable: true
always_in_context: false
palette: "issued-grey"
parts:
  jaw: "default-jaw-01"
  eyes: "default-eyes-01"
  mouth: "default-mouth-01"
  brow: "default-brow-01"
overlays: []
accoutrements: ["id-badge"]
crt_overlay: true
scanline_intensity: 0.3
---

# appearance

how I look. these parameters drive the face creator. you can edit them directly here, or use the visual editor (tap my face → "edit").

the defaults give every new b0t a baseline look — issued-grey palette, neutral parts, an ID badge. randomise the parts in the editor for a fresh starting point.

## what each field does

- **`palette`:** which curated palette I use. options ship in the app — see [palettes](#palettes) below.
- **`parts`:** which jaw / eyes / mouth / brow I have. each is a sprite atlas in the assets.
- **`overlays`:** patterns layered over parts (freckles, scanlines, dithering). list of overlay IDs.
- **`accoutrements`:** items added on top (ID badges, antennae, scanner visors, indicator lights). list of accoutrement IDs.
- **`crt_overlay`:** whether the CRT scanline effect renders over me. default true. set false for a cleaner look.
- **`scanline_intensity`:** 0.0 to 1.0. how visible the scanlines are.

## aesthetic notes

(this is a free-text section. write what you want me to look like, in your own words. the model reads this when it's making mood-driven appearance decisions.)

<!-- example:
slightly weathered. the equipment look — like I've been on the job for a while. cool blues with a single warm accent. nothing whimsical.
-->

## palettes

the 12 palettes that ship with v1, each tuned for the cassette-futurism aesthetic:

- `issued-grey` (default) — muted greys with phosphor green accent
- `field-tan` — warm tans with deep navy accent
- `dim-amber` — aged plastic with amber CRT glow
- (others tbd — see `assets/palettes/`)

palettes use named slots (`primary`, `accent`, `shadow`, `highlight`). switching a palette recolours every part coherently.

## constraints

- no raw RGB customisation. palettes are curated for a reason — see [docs/decisions/0007](../../docs/decisions/0007-anatomical-gui-not-chat.md) (aesthetic discipline section).
- accoutrements follow the issued-equipment principle. no whimsy props.
- the face creator enforces these constraints; editing this file directly bypasses them. don't add a palette ID that doesn't exist — the b0t will fall back to default with a journal entry noting the missing asset.
