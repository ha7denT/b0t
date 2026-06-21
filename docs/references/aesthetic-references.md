# aesthetic references

> **Amended 2026-05-29 — read with the reconciliation in mind.** Two shifts override parts of this doc: (1) **Colour — "never blue" is overridden** (§14 Q3, decided). The highlight system is now three semantic colours — yellow `#EAFF3D` (tokens/text), aqua `#3DEAFF` (function/IO), pink `#FF3DEA` (heartbeat/core) — over a muted dark base; see design doc §3.5. The "warm phosphor / never blue" lines below are superseded. (2) **Display idiom — LCD-forward, no bloom/glow** for panels and organs (amendment §9). Whether the b0t **face** stays painterly or goes 1-bit (§14 Q1), and whether the **CRT eye-screen** keeps its scanlines or goes LCD (§14 Q2), await Hayden's UI designs and are settled in ADR-0016 (pending). Until then, treat the CRT/bloom language below as **under reconciliation**, not current law. The Stålenhag/Cobb/Lumon/Teenage-Engineering discipline and the honesty principle are unchanged.

Visual and cultural references that define the b0t aesthetic. When making any aesthetic decision — colour, motion, type, sound, copy, art direction — return to this list. The synthesis at the bottom is the brief; the references above explain why.

## the references

### Simon Stålenhag
*Tales from the Loop, Things from the Flood, The Electric State*

Domestic technology in lived environments. Painterly fidelity that admits to being constructed. A child's bike beside a decommissioned mech in a Swedish field — the technology is matter-of-fact, weathered, present. **The honesty principle:** the design tells the truth about who would have made it and why.

What we take: warm muted palettes, slight grain, technology embedded in the everyday rather than gleaming and futuristic.

### Ron Cobb's *Alien* semiotics
*Alien, 1979 — production design and graphic system*

Restrained, functional, in-fiction industrial design. The MU/TH/UR readouts and Nostromo signage work because they were designed as if Weyland-Yutani's UX team made them with the technology of 1979. Maybe 30 distinct symbols across the entire film, all from the same design office.

What we take: limited semiotic vocabulary, designed as a *system*, not a kit. Functional iconography. No decorative chrome.

### Lumon UI from *Severance*
*Severance, Apple TV+ — production design*

UI that has been in service for thirty years. Simple, weathered, beige, monospaced, faintly clunky. It is not styled — it is *issued*. Activity is rare and meaningful. When the dot bounces on the marker line, it *means something*.

What we take: ambient quiet, restraint in motion, small type used confidently, the issued-not-styled feeling.

### Death Stranding's operational interfaces
*Death Stranding, Kojima Productions — UI direction*

Cargo lists, route planning, structure building rendered as if Bridges (the in-fiction company) genuinely shipped this UI to its porters. Cold blues and whites, technical type, subtle motion, no flash. Equipment that ages with use.

What we take: technical UI rendered with discipline, equipment as a primary metaphor, the way activity surfaces honestly in the chrome.

### Teenage Engineering
*OP-1, Pocket Operators, brand work*

Functional minimalism with emotional warmth. Serious tools that invite play. Their type system, their colour system, their iconography — all restrained, all confident, all with a slight wink. The OP-1's UI is mostly two colours and small type but it has *personality* because every element is considered.

What we take: the discipline. Every element earns its place. The slight wink. Quality of restraint.

### Replaced
*Thunderful Games — pixel art direction*

Pixel art with cinematic chiaroscuro. Sodium-vapour skies, silhouettes against amber, atmosphere and weight without high resolution. Proves that pixel art can have *light*.

What we take: pixel art with intentional lighting. The grid is a substrate for cinematic composition, not a retro affectation.

### Kingdom Two Crowns
*Raw Fury — pixel art direction*

Pixel art with painterly lighting. Golden hours, dappled forest light, reflections, depth. Different from Replaced but the same lesson: the pixel grid forces every light and shadow choice to count.

What we take: pixel art with depth. Foreground/background separation through lighting. Atmosphere over flatness.

### CRT glow and scanlines
*Tradition — Tron, original arcade cabinets, Windows 3.1, a thousand B-movies*

The visible trace of the screen as a physical object. Phosphor decay, bloom, scanline regularity. A way of saying "this is being displayed *to you, here, now,* on a piece of glass with phosphor and electrons."

What we take: subtle CRT overlay (toggleable). Bloom on the active wiring. Warm phosphor — amber, green, cream. Never blue (blue is sterile and tech-coded).

## what unifies all of these

Each reference shares a quality I'd call **diegetic technology**: technology that exists *in the world* of the thing, designed by an in-fiction culture, weathered by use, with a clear job to do. None of it is decorative. None of it is trying to impress you with rendering tricks. All of it looks like it was made by people who had real problems to solve.

The other thread: **restraint**. None of these references are maximalist. They achieve their effect through compression and specificity, not abundance. b0t inherits this — most of the time the app is quiet. Activity has weight because it isn't constant.

## the synthesis

> **A personal AI device issued by a fictional small electronics firm circa 1986. Pixel art rendered with painterly lighting. UI semiotics in the Cobb/Lumon tradition — restrained, functional, slightly aged. Teenage Engineering design discipline. Sound and motion as considered and rare as in *Severance*. The user's b0t is a piece of equipment that ages with use.**

This paragraph is the brief. When in doubt about an aesthetic decision, ask: would the in-fiction firm that issued b0t have done that?

If no, cut it.

## not-references (things to avoid)

- Glassmorphism, blur effects, gradient bloom (this is 2024 SaaS aesthetic — opposite of b0t)
- Skeuomorphic realism (opposite of pixel-art honesty)
- Cute, kawaii, plush (b0t is charming, not cute — see ADR 0007)
- Cyberpunk neons (too tech-coded; we're domestic, not dystopian)
- Modern flat-design illustration (too startup, too generic)
- Apple's own SF Symbols-as-decoration aesthetic (too clinical, too 2020s)
- Y2K nostalgia (too ironic; we're earnest)

## notes for the design system

- **Type:** IoskeleyMono NL (brain), Söhne (chat). No exceptions in v1.
- **Colour:** warm darks (never pure black), phosphor accents (warm hues only — amber, green, cream, never blue), curated palettes only (no RGB picker).
- **Motion:** restraint. Idle is never static, but it's quiet. Activity is meaningful.
- **Sound:** OP-1 / classic Mac sensibility, never chiptune, never modern UI sounds.
- **Copy:** see [voice-and-copy-guide.md](voice-and-copy-guide.md). Cassette-futurism applies to language too.

## additional viewing for the team

If the references above don't yet click, watch/look at:

- *Severance* season 1 — pay attention to the Lumon UI specifically
- *Alien* (1979) — pay attention to the Nostromo signage and MU/TH/UR
- Stålenhag's *Tales from the Loop* book (the artwork, not the show)
- Outer Wilds — the ship's console as diegetic UI
- Death Stranding — menus and cargo screens specifically
- Teenage Engineering's product pages (op-1.com, teenage.engineering)
- Replaced trailer footage on YouTube
- Kingdom Two Crowns gameplay footage
