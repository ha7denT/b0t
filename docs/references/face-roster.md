# Face roster — manufacturers, models, prompts

Source-of-truth for prompt provenance. Each Manufacturer entry includes its base prompt template; each Model under it includes the full Gamelabs prompt that produced (or will produce) its three Parts.

The runtime catalogue is `b0tApp/Resources/manufacturers.json` — that file ships only what's currently buildable. This document captures the full design intent for the v1 launch lineup and beyond.

Vocabulary per the [2026-05-04 amendment](../b0t-amendment-2026-05-04.md): Manufacturer / Model / Part (Skull, Eyes, Jaw) / Palette / Decal.

---

## Wundercog Industries

**Base prompt template:**

> Pixel art at 256×256 resolution, forward-facing portrait, pure black background, head and jaw only, no neck or body, bot looking directly at camera, perfectly centered. Manufacturer design language (constant): matte off-white polymer shell, soft bulbous forms, no sharp edges, friendly utility aesthetic. Universal interchange (constant across entire roster): the eye-panel underneath is a standard rectangle with content visible only through the skull's cutout window; the jaw is a separate part that mounts to a standard hinge point at the lower edge of the skull, with the jaw seam positioned just above where a "mouth" would sit so the upper lip-equivalent is part of the jaw module; the skull occludes the sides of the jaw and houses the speaker behind the jaw plane (no speaker grille on the jaw itself). Stålenhag/Cobb design logic: plausible polymer construction, subtle wear at contact points.

**Identity:** Friendly utility aesthetic, plausible polymer construction, subtle wear at contact points.

### b0t-01 Hilfer (tier 1 — starter / onboarding)

- **Skull:** classic egg-shaped ovoid silhouette, slightly taller than wide, gently domed crown, perfectly symmetrical, the smallest Wundercog skull, off-white polymer with crisp panel seams.
- **Eye-panel cutout:** wide single horizontal slot in the upper third of the face, simple rounded-rectangle shape with a thin mint-green polymer bezel.
- **Eye-panel content visible:** two soft mint-green rounded rectangles as eyes with implied blink animation, gentle attentive expression.
- **Jaw:** small rounded muzzle module in matching off-white polymer, narrow visible width, a subtle horizontal seam line near the top of the jaw module suggesting the upper lip-equivalent, mint-green accent line along the lower edge of the jaw, the seam where it meets the skull is a single-pixel mint-green line.
- **Palette:** clean off-white polymer, mint-green accents.

### b0t-02 Tüftler (tier 2)

- **Skull:** wider than Hilfer's with a flatter crown, asymmetric — magnifier optic on a swing-arm at the right temple, small tool-rack mount on the upper-left crown, workshop wear shown as scattered darker pixels near one panel seam.
- **Eye-panel cutout:** wide horizontal slot but with a thicker butter-yellow bezel and small indicator-light apertures along the upper edge of the cutout.
- **Eye-panel content visible:** butter-yellow rounded eye shapes with schematic-icon pixel patterns crossing the display, focused tinkering expression.
- **Jaw:** wider than Hilfer's in matching off-white polymer, with a small ventilation aperture in the lower-right of the visible jaw face, a horizontal seam line near the top of the jaw module, butter-yellow accent line along the lower edge, faint solder discoloration on the polymer.
- **Palette:** off-white polymer with workshop wear, butter-yellow accents.

### b0t-03 Meister (tier 3)

- **Skull:** largest and most architecturally complex Wundercog skull, asymmetric — primary sensor cluster (antenna stub plus secondary lens) on upper-left crown, refined cooling vent array on the right temple, crown domes asymmetrically toward the sensor cluster, additional panel divisions throughout, pearlescent off-white with pewter underchassis at panel gaps.
- **Eye-panel cutout:** wide horizontal slot with a deep plum bezel and integrated dual sensor strips above and below the cutout cut into the skull surface.
- **Eye-panel content visible:** deep plum eye shapes with the most intricate iris/pupil pixel detail in the Wundercog line, calm authoritative gaze.
- **Jaw:** largest Wundercog jaw in pearlescent off-white polymer, with a small ventilation cluster on the lower-left balancing the asymmetric skull crown, brushed pewter detail at the visible hinge points, a horizontal seam line near the top of the jaw module, deep plum accent along the lower edge.
- **Palette:** pearlescent off-white with pewter accents, deep plum highlights.

---

## Kalv

**Base prompt template:**

> Pixel art at 256×256 resolution, forward-facing portrait, pure black background, head and jaw only, no neck or body, bot looking directly at camera, perfectly centered. Manufacturer design language (constant): plywood front face with brushed metal frame and visible corner fasteners, rectilinear silhouette, monochrome OLED screen content visible through cutout. Universal interchange (constant across entire roster): standard rectangular eye-panel underneath, jaw mounts to standard hinge point, jaw seam positioned just above mouth-line so the upper edge is part of the jaw module, skull occludes jaw sides and houses the speaker behind the jaw plane. Stålenhag/Cobb design logic: honest materials, every fastener earned, visible wear from real use.

**Identity:** Honest materials. Every fastener earned. Visible wear from real use.

### Kalv Lit (tier 1)

- **Skull:** small near-square front face, the smallest Kalv silhouette, no rounded edges, simple aluminum corner fasteners, symmetrical, warm birch plywood with brushed aluminum frame.
- **Eye-panel cutout:** small rectangular cutout in the upper portion of the face with a brushed aluminum bezel.
- **Eye-panel content visible:** soft white rounded-rectangle eye shapes with a single small status icon in the corner, warm white halo glow.
- **Jaw:** narrow brushed aluminum drop-panel matching the skull width, low visible profile, a fine cream wool felt strip along the top edge of the jaw module (the jaw seam, doubling as the upper lip-equivalent), small aluminum fastener pixels at each lower corner of the jaw.
- **Palette:** warm birch plywood, brushed aluminum, cream wool felt, warm white OLED.

### Kalv Verk (tier 2)

- **Skull:** tall and narrow rectangular front face (the tallest Kalv silhouette), asymmetric — tool-mount bracket on the upper-right where a small inspection optic deploys, heavier corner fasteners with visible bluing, sawdust pixels in seams, dark walnut plywood with bluing-finished steel frame.
- **Eye-panel cutout:** medium rectangular cutout with a steel bezel, slightly larger than Lit's, positioned slightly higher on the taller face.
- **Eye-panel content visible:** amber eye shapes flanked by small tool-icon overlays.
- **Jaw:** heavier bluing-finished steel drop-panel wider than Lit's, charcoal wool felt strip along the top edge (jaw seam and upper lip-equivalent), heavier steel fastener pixels at the lower corners, fingerprint smudges on the metal surface.
- **Palette:** dark walnut plywood, bluing-finished steel, charcoal wool felt, amber OLED.

### Kalv Nett (tier 3)

- **Skull:** widest and shortest Kalv silhouette (this unit is wall-mounted infrastructure), markedly different proportions from Lit and Verk — wider than tall, polished copper frame with prominent corner fasteners, multiple small status indicator clusters arranged asymmetrically across the front panel, dark slate front instead of plywood.
- **Eye-panel cutout:** wide rectangular cutout with a copper bezel, the widest eye-cutout in the Kalv line.
- **Eye-panel content visible:** cool white eye shapes flanked by multiple data-stream readouts (the most information-dense Kalv display).
- **Jaw:** minimal narrow polished copper drop-panel with verdigris pixels at edges, low visible profile, no felt seam (sealed unit) — instead a clean copper-on-slate seam line along the top edge serving as the upper lip-equivalent, small copper fastener pixels at the lower corners.
- **Palette:** dark slate, polished copper with verdigris edges, cool white OLED.

---

## Hartsyzk Robotyka

**Base prompt template:**

> Pixel art at 256×256 resolution, forward-facing portrait, pure black background, head and jaw only, no neck or body, bot looking directly at camera, perfectly centered. Manufacturer design language (constant): angular faceted armor plates with exposed hex fasteners, MOLLE-style attachment points, stencil-style unit numbering on the upper-left plate, dual-screen content visible through cutouts behind polycarbonate. Universal interchange (constant across entire roster): standard rectangular eye-panel underneath, jaw mounts to standard hinge point, jaw seam positioned just above mouth-line so the upper edge is part of the jaw module, skull occludes jaw sides and houses the speaker behind the jaw plane. Stålenhag/Cobb design logic: field-deployable, repairable, every panel justified.

**Identity:** Field-deployable, repairable, every panel justified.

### HR-Skaut (tier 1)

- **Skull:** low-profile narrow faceted helmet (the smallest and most aerodynamic Hartsyzk silhouette), built for movement, symmetrical, single small antenna stub on one temple, dust pixels in panel seams, forest camo armor — deep greens, browns, black disruption pattern.
- **Eye-panel cutout:** dual narrow horizontal cutouts (twin slots side by side) behind a single narrow polycarbonate cover, scratched and scuffed.
- **Eye-panel content visible:** amber eye shapes as compact pixel clusters with reticle-cross overlays, alert scanning expression.
- **Jaw:** narrow forest-camo armored plate matching the skull profile, a horizontal armored seam ridge along the top edge of the jaw module (the jaw seam, doubling as the upper lip-equivalent and rendered as a slight raised edge), small hex fastener pixels at the lower corners, faint scratches from undergrowth contact.
- **Palette:** forest camo, scuffed hardware, amber screen glow.

### HR-Strateh (tier 2)

- **Skull:** medium faceted helmet wider than Skaut's, asymmetric — holographic projection emitter prominently mounted on the upper-right temple as a recognizable structure (this unit's defining feature), small antenna array on the upper-left, more rectangular crown profile, urban camo armor — greys, blacks, off-white disruption.
- **Eye-panel cutout:** dual rectangular cutouts (twin rectangles) behind a clean polycarbonate cover, larger than Skaut's narrow slots.
- **Eye-panel content visible:** blue-white eye shapes with map-grid overlay pixels animating across them, analytical expression.
- **Jaw:** wider urban-camo armored plate, horizontal armored seam ridge along the top edge as the upper lip-equivalent, urban camo accent strip along the lower edge, small hex fastener pixels at the lower corners, less wear than Skaut's.
- **Palette:** urban camo, blue-white screen glow.

### HR-Heneral (tier 3)

- **Skull:** most refined faceted Hartsyzk silhouette, vertical proportion, subtly asymmetric — ceremonial-feeling antenna elements at both temples at slightly different heights and forms, more decorative stencil markings, weathered dust accumulation in seams, martian tundra palette — rust red, oxidized iron, dust orange, copper hardware.
- **Eye-panel cutout:** dual stylized cutouts with subtle copper-pixel framing, polycarbonate cover with a refined edge treatment.
- **Eye-panel content visible:** deep-red eye shapes with the most intricate eye pixel detail in the Hartsyzk line, command-architecture overlay pixels, gravitas.
- **Jaw:** refined martian-tundra armored plate with copper edge details, a more refined horizontal armored seam ridge along the top edge as the upper lip-equivalent, copper fastener pixels at the lower corners, faded stencil along the lower edge.
- **Palette:** martian tundra, copper hardware, deep-red screen glow.

---

## Solace Synthetics

**Base prompt template:**

> Pixel art at 256×256 resolution, forward-facing portrait, pure black background, head and jaw only, no neck or body, bot looking directly at camera, perfectly centered. Manufacturer design language (constant): silicone flesh surface with visible decorative seam lines, organic humanoid skull silhouette with deliberate small departures from human proportion, circular eye-screen content visible through skull cutouts with iris-like ring diodes. Universal interchange (constant across entire roster): standard rectangular eye-panel underneath the round visible windows, jaw mounts to standard hinge point, jaw seam positioned ABOVE THE UPPER LIP so the upper lip is part of the jaw module — this means a Solace jaw attached to any skull will read as a complete mouth, and a non-Solace jaw attached to a Solace skull will sit at the same anatomical position. Skull occludes jaw sides and houses the speaker behind the jaw plane. Stålenhag/Cobb design logic: honest about being synthetic, every seam acknowledged.

**Identity:** Honest about being synthetic. Every seam acknowledged.

### Solace Mira (tier 1)

- **Skull:** youthful adult cranial proportion, rounder face with softer cheek and jaw definition, symmetrical, stylized soft-material hair as a distinct pixel block in a relaxed swept style framing the face, visible seam pixel lines at hairline, warm beige silicone flesh, a faint horizontal seam pixel line just above where the upper lip would sit (showing where the jaw module meets the skull).
- **Eye-panel cutout:** pair of circular cutouts in human eye-socket positions, soft pink ring diode halos around each cutout edge.
- **Eye-panel content visible:** soft pink iris-like circles with subtle pupil pixel motion, gentle attentive expression with implied blink animation.
- **Jaw:** small soft warm-beige silicone jaw module containing the entire mouth area (upper lip, lower lip, chin), youthful rounded lip form rendered with careful pixel placement, narrow visible width proportional to the rounder face, the upper edge of the jaw module sits just above the upper lip and meets the skull at a faint silicone seam line, small temple diode visible at the seam line.
- **Palette:** warm beige silicone, soft pink diode glow, brown stylized hair.

### Solace Vesna (tier 2)

- **Skull:** mature adult cranial proportion with more defined cheekbones and brow rendered through silhouette adjustment, symmetrical with grounded weight in the proportions, stylized hair pixel block in a longer grounded style with visible side seam where it meets the silicone, olive-toned silicone flesh, a faint horizontal seam pixel line just above where the upper lip would sit.
- **Eye-panel cutout:** pair of circular cutouts in human eye-socket positions, amber ring diode halos around each cutout edge.
- **Eye-panel content visible:** amber iris-like circles with steadier iris detail than Mira (less blink animation, more sustained attention), contemplative expression.
- **Jaw:** medium olive-toned silicone jaw module containing the upper lip, lower lip, and chin, more defined adult lip form than Mira's, wider visible width, the upper edge of the jaw module meets the skull at a slightly more pronounced silicone seam line, diode visible behind where the ear would be.
- **Palette:** olive-toned silicone, amber diode glow, dark stylized hair.

### Solace Sage (tier 3)

- **Skull:** elder cranial proportions with intentional asymmetry — slightly different brow heights, time-marked features, deeper seam pixel lines, stylized soft grey hair pixel block in a settled longer style, deep umber silicone flesh, a more pronounced horizontal seam pixel line just above where the upper lip would sit (the deepest jaw-seam in the Solace line, suggesting accumulated articulation).
- **Eye-panel cutout:** pair of circular cutouts with warm gold ring diode halos, the most intricate halo treatment in the Solace line.
- **Eye-panel content visible:** warm gold iris-like circles with the most complex pupil structure in the Solace line, deeply expressive longitudinal warmth.
- **Jaw:** wide deep-umber silicone jaw module containing the upper lip, lower lip, and chin, settled lip form with intentional silicone-wear pixels at the lip edges (subtle texture suggesting years of articulation), the widest visible Solace jaw, the upper edge meets the skull at a deep silicone seam line, gold diode placed at the collarbone seam.
- **Palette:** deep umber silicone, warm gold diode glow, soft grey stylized hair.

---

## Kernel Collective

**Base prompt template:**

> Pixel art at 256×256 resolution, forward-facing portrait, pure black background, head and jaw only, no neck or body, bot looking directly at camera, perfectly centered. Manufacturer design language (constant): modular assembled construction with visibly bolted components, exposed cable runs, heat sink fins as functional ornament, audio array of small microphones above the eye-area, dual rectangular screen content visible through cutouts in exposed bezels. Universal interchange (constant across entire roster): standard rectangular eye-panel underneath, jaw mounts to standard hinge point with visible mechanical actuator, jaw seam positioned just above mouth-line so the upper edge is part of the jaw module, skull occludes jaw sides and houses the speaker behind the jaw plane. Stålenhag/Cobb design logic: assembled by other machines, never touched by human hands, every component justified.

**Identity:** Assembled by other machines, never touched by human hands. Every component justified.

### kc-init (tier 1)

- **Skull:** minimal narrow rectilinear modular skull, the smallest and most stripped-down Kernel form, symmetrical, simple parallel heat sink fin pattern at the crown, basic exposed cable runs along the temples, low cable density, matte black aluminum.
- **Eye-panel cutout:** dual small rectangular cutouts in basic black exposed bezels.
- **Eye-panel content visible:** green CRT-phosphor glow eye shapes (rectangles or basic dot-matrix patterns), occasional terminal-text fragments.
- **Jaw:** narrow matte-black aluminum hinged module with a visible mechanical hinge actuator pixel cluster at each side where it meets the skull, a thin horizontal mechanical seam ridge along the top edge of the jaw module (the jaw seam, doubling as upper lip-equivalent), low visible profile.
- **Palette:** matte black aluminum, green CRT glow, raw aluminum fasteners.

### kc-fork (tier 2)

- **Skull:** medium rectilinear modular skull wider than kc-init's, asymmetric — secondary close-focus optic deploys on a small arm from the right temple (visible folded against the skull), more refined heat sink fin pattern, additional cable runs across the upper crown, gunmetal aluminum with amber anodized accents.
- **Eye-panel cutout:** dual medium rectangular cutouts in gunmetal exposed bezels with amber accent strips along the bezel edges.
- **Eye-panel content visible:** amber glow eye shapes with clearer iris/pupil pixel structure than kc-init, occasional code-syntax fragments (curly braces, semicolons rendered as pixel glyphs).
- **Jaw:** wider gunmetal hinged module than kc-init's with more visible mechanical hinge actuator pixels at each side, amber accent line along the lower edge, a horizontal mechanical seam ridge along the top edge as upper lip-equivalent, more articulated visible form.
- **Palette:** gunmetal aluminum, amber anodized accents, bare aluminum manipulator hardware.

### kc-oracle (tier 3)

- **Skull:** most refined and largest Kernel skull, deliberately asymmetric — multiple sensor systems beyond the primary eye-area arranged asymmetrically (secondary sensor cluster on upper-left, antenna array on upper-right at a different height), transparent armor sections revealing magenta-glowing coolant lines, brushed titanium accent panels, bare aluminum frame.
- **Eye-panel cutout:** dual rectangular cutouts in bare aluminum exposed bezels with brushed titanium accent strips.
- **Eye-panel content visible:** magenta glow eye shapes with the most intricate pixel detail in the Kernel line, subtle architectural-diagram overlay pixels.
- **Jaw:** largest bare-aluminum hinged module with refined mechanical hinge actuator pixel detail at each side, magenta-glowing internal coolant lines visible through gap pixels along the lower edge of the jaw, brushed titanium accent strips, a refined horizontal mechanical seam ridge along the top edge as upper lip-equivalent.
- **Palette:** bare aluminum, brushed titanium accents, magenta anodized accents, magenta coolant glow.

---

## Notes on the roster

- **Visual cohesion across Manufacturers** is enforced through three mechanisms per amendment §2.4: shared master palette substrate, shared silhouette grammar (bounding-box rules, hinge geometry), and shared weathering/grain treatment via a base prompt template every Manufacturer's prompts inherit from.
- **Once unlocked, Parts mix freely.** Manufacturers are origins, not silos. The "Frankenstein b0t" path is explicitly supported.
- **Three Parts only** per Model: Skull, Eyes (eye-screen panel mounted behind the cutout), Jaw. Decals are a separate render layer per amendment §1, not a Part.
- **Phase 4 ships only Hilfer's three Parts via Gamelabs.** The other 14 Models in this roster are reference for Phase 6+ content drops.
