# b0t implementation amendment — 2026-05-29

**Status:** Active — awaiting Claude Code interpretation pass
**Author:** Jamee
**Supersedes / amends:** prior decisions on the inference engine, v1 face scope, multi-b0t scope, and aesthetic display metaphor. Touches the 2026-05-04 amendment, the design document, the PRD, README, CLAUDE.md, and shipped code in Phases 2 and 4.
**Scope of impact:** **This amendment is NOT largely additive.** Unlike 2026-05-04, it reverses at least one locked PRD non-negotiable, redirects shipped code in `b0tCore` (Phase 2) and `b0tFace`/`b0tHome` (Phase 4), and moves several features previously scoped for v1 into v2. Read §0 before acting.

---

## 0. How Claude Code should process this amendment

This document records decisions made by Jamee in a design session. It is the new source of truth where it conflicts with earlier documents. However:

1. **Apply the items marked DECIDED.** These are settled. Revise the relevant docs and code to match.
2. **Do NOT resolve the items in §14 (Open questions).** They are genuinely undecided and require Jamee's input, per the project's standing rule ("surface ambiguity, do not silently resolve" — CLAUDE.md conventions, PRD §0). Where this amendment notes a *recommended* resolution, treat it as a suggestion to put to Jamee, not a decision.
3. **Supersede, do not delete.** ADRs are append-only. Where this amendment overturns a settled decision, author a new ADR that references and supersedes the old one (see §13). Do not edit historical ADRs except to add a "Superseded by ADR-NNNN" header line.
4. **This reworks shipped phases.** Treat §2 (inference) and §5 (face) as re-opening Phase 2 and Phase 6 respectively, and as partially invalidating Phase 4 assumptions. Update `docs/IMPLEMENTATION.md` (the tracker) and re-sequence the phase ledger accordingly (§12).
5. **Begin by producing an interpretation plan, not code.** Before touching anything, produce a short written plan that lists: which docs change, which ADRs supersede which, which shipped code is affected, and which §14 questions block which work. Surface that plan to Jamee for approval first.

---

## 1. Positioning — tool-first (DECIDED)

The product is now framed as **a local-AI tool with companion styling**, not a companion that happens to be useful. "Productivity can be fun" is the guiding line: the companion layer is texture over a genuinely useful local-AI utility, and the texture must never tax the utility.

This inverts design document §1.3, which currently lists "a productivity tool with a face on it" under *what b0t is not*. That framing is now wrong.

What this changes:
- Design doc §1 (Philosophy) and §1.3 (What b0t is not) need rewriting to lead with utility, with companionship as the differentiator rather than the thesis.
- App Store positioning, onboarding emphasis, and what the home screen foregrounds all shift toward "what can it do for me" first.

What this does **not** change: the four pillars (markdown brain, configurable heartbeat, anatomical GUI, user-assembled b0t) and the ownership thesis survive intact. The "you own your b0t, it's local plain markdown" spine is unaffected and is in fact reinforced by §2.

---

## 2. Inference engine — downloadable open-weight models, not Apple Foundation Models (DECIDED — reverses a locked non-negotiable)

b0t v1 will run on **downloadable open-weight models executed locally** (e.g. Llama 3.2 1B, Qwen3 1.7B), not Apple's Foundation Models framework.

**Rationale:** Apple Intelligence / the Foundation Models framework requires A17 Pro hardware (iPhone 15 Pro or newer). That excludes a large installed base, including Jamee's own iPhone 13 Pro (A15). Bringing a downloadable model widens device support and strengthens the ownership thesis — the user chooses and owns the brain.

This **reverses PRD §2 non-negotiable #1** ("All AI inference is on-device via Apple Foundation Models"). It does **not** weaken the *on-device, no-cloud* principle — inference remains fully local. Non-negotiables #2, #3, #5 (markdown, no telemetry, no cloud fallback) all stand and are reinforced.

**Code impact — this re-opens Phase 2 (shipped 2026-05-04).** The following shipped constructs in `b0tCore` are Foundation-Models-specific and must be replaced or abstracted behind an engine-agnostic interface:
- `LanguageModelSession` (FM-only) → a local inference session over the chosen runtime.
- `TickDecision` as `@Generable` → `@Generable` is an FM macro; structured output must be reimplemented (grammar-constrained / JSON-schema decoding against the local runtime).
- `ContextAssembler` token budget hardcoded to 3500/4096 → the context window is now **model-dependent and variable** (see §7). Re-base budgeting on the loaded model's actual context length.
- PRD §3.3 (Foundation Models session pattern) and §3.2 (data flow diagram referencing FM `@Generable`) are now historical; rewrite.
- PRD §10.5 and §13 instruct Claude Code to use Apple's Foundation Models docs as source of truth — replace with the chosen runtime's docs.

**Recommended (subject to §14):** abstract inference behind a protocol (`InferenceEngine` or similar) so the FM path could return later as one engine among several, and so the rework is a new conformer rather than a teardown.

---

## 3. Model catalogue, lifecycle, and the content/format boundary (DECIDED)

The model lives behind the **processor organ** ("main processor"). Model selection, switching, parameters, install/download, and storage state are all surfaced in the processor organ's inspector (see §6).

**New subsystems required (none of these exist yet):**
- **Download manager** — resumable, storage-aware (these files are hundreds of MB to >1GB), background-capable. Handles storage-full gracefully.
- **Model lifecycle** — load/unload to stay under iOS memory (jetsam) limits. On a 6GB device (iPhone 13 Pro target) the practical ceiling is ~2–3GB resident, which is why the catalogue caps at small models (~1–2B quantised).
- **Per-model chat templating** — the critical correctness gotcha. See the content/format boundary below.

**The content/format boundary (architectural rule):**
- **Content layer** — what the organs produce (identity/personality, heartbeat instructions, memory, module specs). Plain markdown, **model-agnostic**, user-authored. Organs own this. This is the existing markdown-brain layer.
- **Format layer** — how assembled content is wrapped into the exact token sequence a given model expects (chat template, special tokens; e.g. Llama's `<|start_header_id|>…<|eot_id|>` vs Qwen's ChatML `<|im_start|>…<|im_end|>`). **Model-specific. Processor-owned. Not user-edited.**

A chat template is **not** a "prompt prefix" and must not be modelled as editable organ content — it wraps every turn and is tokenizer-specific; a wrong template degrades output silently with no error. **Preferred implementation:** drive the runtime through its messages/chat-completion API and let it apply the model's own embedded template (GGUF metadata carries it), so the format follows the weights automatically on model switch. Optionally expose the template **read-only** in the processor inspector with an "advanced: override" affordance clearly marked as able to break output (fits the tinker-friendly audience without making the happy path fragile).

---

## 4. v1 scope reduction — modular face, manufacturers, gallery, and unlock economy move to v2 (DECIDED)

v1 ships **one b0t with one face**. The full apparatus from the 2026-05-04 amendment — multiple Manufacturers, multiple Models, the Parts/Decals/Palette generation system, the gallery of up to 6 b0ts, and heartbeat-as-unlock-currency — is **deferred to v2, conceptually preserved**.

This means most of the 2026-05-04 amendment becomes v2 scope. Do not delete it; mark it "v2 — deferred 2026-05-29" and keep it as the v2 design.

Affected:
- Design doc §2.4 (multi-b0t, gallery, cap 6), §2.5 (Face Creator: parts/decals/palettes), §10 (v1-vs-v2 split — rewrite: move Face Creator and multi-b0t roster to v2).
- 2026-05-04 amendment §2.1–2.4 (parts/Manufacturers/baked palettes), §3.1 (gallery), §3.2 (heartbeat unlock economy), §3.3 (pre-built vs build-your-own) → all v2.
- PRD §2 non-negotiable #8 (multi-b0t single-active-heartbeat, cap 6) → softened to single-b0t for v1.
- PRD §3.1 — the `FaceCreator/` and `Gallery/` app source groups are not v1 surfaces.
- IMPLEMENTATION.md ledger — Phase 6 (Face rig + Parts + Face Creator) and Phase 7 (Multi-b0t + Gallery) are re-scoped; see §12.

**Disentangle the two roles of "heartbeat"** — they have been conflated:
- **Heartbeat as scheduler / proactive loop** (design doc §2.2) — the core autonomous mechanism. **KEEP in v1.**
- **Heartbeat as unlock currency** (2026-05-04 §3.2, "per Open Claw definition") — only meaningful when there are Models to unlock. **DEFER to v2.**

---

## 5. The face in v1 — single pre-composed unit, sprite-sheet states, illuminated speaker grille (DECIDED)

- The face is a **single unit**, not runtime-composited from Skull/Eyes/Jaw parts. Mood states are authored as **sprite-sheet animations** (the ~8 mood states stand).
- **No moving mouth/jaw in v1.** Speech is signalled by a **speaker grille that illuminates**, not by lip/jaw animation. This removes the mood-×-mouth combinatorial problem entirely.
- **Grille behaviour:** intensity is driven by the speech signal — TTS amplitude envelope if audio is present, or token-emission rate if text-only (see §14 on whether v1 has TTS). The grille pulses in the "tokens" highlight colour (yellow), tying it to the token semantics in §8.
- **Clean separation of concerns:** mood sprites carry emotion/aliveness (eyes, brow); the grille carries speech/activity. The two channels are independent.

**What survives from existing/planned face work (do not discard):**
- ADR-0003 (SpriteKit + SwiftUI) stands.
- The MoodController state machine, SKAction sequences, and the motion-vocabulary library all stand — they now *select* a pre-rendered sprite-sheet animation rather than animating composited parts.
- The manifest/catalogue contract **shape** stands; populate it with a single pre-composed unit so the v2 modular system is *additive* (new manifest entries), not a re-architecture.

**What is deferred (to v2 with the modular system):** the `FacePart` protocol and its `SkullNode`/`EyesNode`/`JawNode` conformers as a *runtime-composited* rig; `DecalNode`; per-part palette variants.

**Code impact on Phase 4 (shipped):** Phase 4 shipped a static 3-part face (Skull/Eyes/Jaw composited, painterly lighting, CRT eye-screen). Decide (Jamee, §14) whether the v1 single face replaces that composition with a single sprite or keeps the composed look but animates it as one unit. Either way, the moving Jaw is dropped and a grille element added.

---

## 6. Organ inspector — up to three tabs, render only what an organ declares (DECIDED)

Tapping an organ opens its inspector in the lower half of the screen (extends the existing design doc §2.3 "tap organ → .md in lower half" and the shipped `OrganInspectionView`/`InspectionPanel` from Phase 4). The inspector supports **up to three tab types; an organ renders only the tabs it declares** (three is the maximum depth, not a fixed requirement — confirmed by the heartbeat organ, which has only a single `.md`):

1. **Controls** — buttons/sliders bound to frontmatter (e.g. heartbeat BPM, which modules load). This already exists as "frontmatter-as-controls" in `b0tHome`.
2. **Directory** — the organ's file tree (module/diary/memory contents). Styled as an LCD panel. **New** relative to Phase 4.
3. **`.md` viewer/editor** — the file selected in the Directory tab; tapping opens full-screen for editing. The full-screen `EditorView` already exists.

**Backlight colour is semantic** (see §8): Directory panels back-light aqua (functional), `.md` panels back-light yellow (text/tokens), and the heartbeat's `.md` back-lights pink (heart/emotional core).

The processor organ's three tabs map cleanly: Controls = model switch + inference params; Directory = installed/downloadable models + storage state (home of the download manager); `.md` = model notes/readme (and optionally the read-only chat template per §3).

---

## 7. Prompt assembly as slot-based composition (DECIDED)

Most organs contribute to the prompt (identity, heartbeat, memory, modules). Model this explicitly: **organs are prompt fragments with a UI.** The assembled prompt is the composition of organ contributions.

**Required:** each organ's contribution declares **where it lands** — a `slot` (e.g. `system`, `prepended_context`, `per_turn`, `tool_defs`) — rather than being blindly concatenated. Fold the `slot` field into the existing manifest/catalogue contract. This keeps assembly deterministic without building a bespoke templating engine.

This is the content layer of the §3 boundary. `ContextAssembler` (currently FM-shaped) becomes: gather declared organ fragments by slot → assemble role-tagged messages → hand to the runtime, which applies the model's own format layer.

---

## 8. Token metering (DECIDED — extends the existing energy-wiring concept)

Surface token usage as a **resource gauge with a denominator**, not a bare count. The denominator is the **loaded model's context window** (variable per model, per §2/§3) — meaningful precisely because on-device context is tight.

- **Per-organ attribution** falls out of the §7 slot architecture for free: each organ's contribution has a token subtotal. Each organ can show its own cost in its inspector; the processor shows the total against the ceiling.
- **Two-directional "yellow" flow** unifies two features: input tokens accumulate *into* the processor as the prompt assembles; output tokens stream *out* via the grille (§5). Yellow is the shared currency. This extends the existing in/out energy-wiring pulse (design doc §2.3) rather than inventing a new visual.
- **Tokenizer-specific:** counts are valid only for the loaded model and shift on model swap. Compute with the active model's tokenizer; recount on content change or model swap, not per frame. Include structural/template token overhead, not just organ content.
- **Restraint (REQUIRED):** keep it ambient and diegetic — a gauge at the processor with per-organ breakdown on drill-in. **Do not build a metrics dashboard.** This is the b0t's visible metabolism, not analytics.

---

## 9. Aesthetic — LCD-forward, muted base, three semantic highlight colours (PARTLY DECIDED; conflicts flagged to §14)

**DECIDED — display metaphor is LCD, not CRT/LED/neon.** The panel idiom is a backlit monochrome LCD (handheld-game / calculator / lab-instrument): low contrast, matte, monochrome high-res pixels behind a *tinted backlight*, visible pixel grid, **no bloom, no glow** (bloom/glow reads as LED). Faint ghosting/persistence is on-idiom. This is consistent with the warm-amber backlit LCD panel already shipped in Phase 4 (`LCDPalette`) — the change is the *colour* of the backlight, not the technique.

**DECIDED — three semantic highlight colours over a muted dark surface:**
- yellow `#EAFF3D` — tokens, text, brainpower
- aqua `#3DEAFF` — the functional medium (I/O, plumbing, modules)
- pink `#FF3DEA` — the heartbeat, core ideas, emotional states

Most of the surface stays muted/dark and unsaturated; these are emphasis-only (buttons, highlights, panel backlights per organ semantic).

**CONFLICTS to surface (do NOT silently resolve — §14):**
- Design doc §3.5 states "warm phosphor — amber, green, or cream. **Never blue**." Aqua `#3DEAFF` is a cyan/blue and pink is magenta. The new palette overrides the "never blue / warm phosphor" rule. This is Jamee's to confirm as an explicit override.
- Design doc §3.3/§3.6 specify CRT/phosphor with "slight bloom and scanline" and "CRT warming" transitions. The LCD-no-bloom direction contradicts this. Phase 4 shipped a CRT scanline shader **on the eye-screen only**. Whether the eye-screen keeps its CRT treatment or also goes LCD is undecided (§14).
- Design doc §3.3 layers the b0t face as "pixel art with painterly lighting." The new UI/organ direction is 1-bit monochrome (§10). Whether the *face itself* goes 1-bit or stays painterly is undecided (§14).

---

## 10. Asset pipeline for v1 — purchased 1-bit packs + Aseprite, runtime tinting (DECIDED)

v1 UI chrome and organs are built from **piiixl 1-bit asset packs, scaled up**:
- `2000+ Pixel Icons Pack` (mega-1-bit-icons-bundle) — organ/iconography source.
- `1bit_UI` — UI chrome (panels, buttons, sliders, progress bars).

**Licensing verified (2026-05-29):** both are piiixl custom commercial licenses permitting use and modification in commercial/paid projects; the only restriction is no redistribution of the packs as standalone files (not a concern here). Attribution not required. Tagged no-generative-AI. **Workflow note:** elements ship largely as sprite sheets, not pre-sliced files — budget Aseprite slicing time.

**Recolouring approach:** 1-bit art is effectively a mask, so per-context tinting (yellow/aqua/pink) is a simple runtime colour-blend on monochrome assets. **This is NOT the same as, and does not revive, the deferred Gamelabs baked-palette-variant pipeline (2026-05-04 §2.2), nor a face-part palette shader** (the project deliberately chose baked variants and no runtime palette shader for faces). Keep UI-mask tinting and face-part palettes as separate concerns; the former is v1, the latter is deferred with the v2 modular face.

**Resolves a pending item:** the Gamelabs Studio / "Hilfer" Part PNGs that Phase 4 left as placeholder red-X squares (IMPLEMENTATION.md, Phase 4 follow-ups) are **superseded for v1** by the piiixl-based single face and organs. PRD §12 Q4 ("Pixel art assets — Gamelabs Studio") is re-opened and re-answered for v1; Gamelabs is deferred with the v2 modular system.

---

## 11. Licensing and attribution obligations (DECIDED — compliance work)

- **Llama models (if shipped/downloaded):** the Llama Community License requires (a) a copy of the license included, (b) **"Built with Llama" displayed prominently** in the UI/about screen, and (c) a `NOTICE` file with the required attribution string. The 700M-MAU clause is irrelevant at this scale.
- **Qwen models:** Apache-2.0 — clean; retain the license/notice. **Recommended default brain** to minimise attribution surface (subject to §14).
- **piiixl packs:** no redistribution of the packs as standalone files; commercial use in the app is permitted (see §10).

Note for the voice-and-copy guide: "Built with Llama" is a legally-required verbatim string and is **exempt** from the all-lowercase styling rule. Flag this so it isn't "corrected" into non-compliance.

This adds App Store metadata / about-screen obligations but does not affect the privacy posture (still no telemetry, no cloud).

---

## 12. Documents, code, and tracker to revise

| Target | Sections | Change |
|---|---|---|
| `README.md` | intro, Status | Replace "Foundation Models framework animates those files" and "3B-parameter local model"; restate inference engine; update phase status (Phase 2 re-opened). |
| `CLAUDE.md` | Philosophy paragraph, Conventions, DoD | Replace Foundation Models claim; tool-first positioning; revise "Aesthetic is non-negotiable / cassette-futurism" to reflect §9 reconciliation once §14 is answered; add `b0tHome/` to the module tree (already-noted drift). |
| `design_document.md` | §1, §1.3, §2.2, §2.4, §2.5, §3.3, §3.5, §3.6, §5.2, §9, §10 | Tool-first thesis; inference engine; defer modular face/gallery to v2; aesthetic reconciliation (§9/§14); re-base the 4096-token memory architecture on variable context windows. |
| `prd.md` | §1, §2 (#1, #8), §3.2, §3.3, §3.4, §10.5, §11, §12 (Q4) | Reverse non-negotiable #1; soften #8 to single-b0t; rewrite FM session pattern and data flow; re-base context budgeting; replace FM-docs source-of-truth; re-open Q4 (assets). |
| `b0t-amendment-2026-05-04.md` | §2.1–2.4, §3.1–3.3 | Mark as v2-deferred (do not delete); keep as the v2 design. |
| `docs/IMPLEMENTATION.md` | ledger, current state | Re-open Phase 2 (engine swap); re-scope Phase 6 (single face, not Face Creator) and Phase 7 (single-b0t, gallery → v2); add new model-download/lifecycle work; record this amendment. |
| `b0tCore` (code) | FM loop | Abstract/replace `LanguageModelSession`, `@Generable TickDecision`, `ContextAssembler` budgeting; add inference engine + download/lifecycle. |
| `b0tFace` / `b0tHome` (code) | face, panels, inspector | Single-unit sprite-sheet face + grille; add Directory tab + render-declared-tabs; re-colour `LCDPalette` to semantic backlights; resolve CRT eye-screen per §14. |
| `b0tDesign` (code) | tokens/palettes | Add the three semantic highlight tokens; 1-bit mask tinting utility. |

---

## 13. New ADRs to author (append-only; supersede, don't edit history)

- **Inference engine: downloadable open-weight models over Foundation Models.** Supersedes the relevant part of any ADR encoding PRD non-negotiable #1; references the device-coverage rationale.
- **v1 ships a single non-modular face; modular Parts/Manufacturers/Models deferred to v2.** Supersedes/extends ADR-0011 (defer face rig) and the 2026-05-04 parts decisions.
- **Speech signalled by illuminated speaker grille; no moving jaw in v1.** References the mood-×-mouth combinatorial rationale.
- **Content/format boundary for prompts; slot-based assembly.** Documents the §3/§7 architecture.
- **(Pending §14) Aesthetic reconciliation: LCD-forward, semantic highlight palette, "never blue" overridden.** Author only after Jamee confirms §14 items.

---

## 14. Open questions for Jamee (DO NOT resolve)

1. **Face visual register.** Does the v1 single face stay "pixel art with painterly lighting," or go 1-bit monochrome to match the new UI/organs? (Affects whether Phase 4's composed painterly face is reworked.)
2. **CRT eye-screen.** Keep the shipped CRT scanline treatment on the eye-screen as the one emissive element, or take the whole surface LCD/no-bloom? (§9)
3. **"Never blue" override.** Confirm the aqua `#3DEAFF` / pink `#FF3DEA` palette formally overrides design doc §3.5. (Recommended: yes, since the hex values were specified deliberately.)
4. **Single-b0t vs multi-b0t in v1.** "v2 we can have different unlockable bots" implies v1 is one b0t with no gallery. Confirm. (Recommended: single b0t in v1; low rework since Phase 7 is unstarted.)
5. **Inference runtime.** llama.cpp (Metal) vs MLX vs MLC-LLM — engineering call. (Recommended: llama.cpp for its embedded-chat-template handling and GGUF ecosystem, which makes safe model-switching almost free.)
6. **Default model + v1 catalogue.** Which models ship/are offered, and which is the default? (Recommended: Qwen3 default for Apache-2.0 simplicity; Llama opt-in with the §11 attribution.)
7. **TTS in v1?** The grille amplitude path needs an audio source. Keep the elaborate `b0tAudio` TTS/effects (design doc §3.7), or text-only for v1 with the grille tracking token rate instead? (Affects Phase 8 scope.)
8. **Trial length.** Design doc/PRD say 7 days; the competitor reference used 3. Pricing stays one-time $19.99/$29.99 either way. Jamee's call pre-launch (PRD §12 Q1).
9. **Minimum-OS / device floor.** With Foundation Models gone, the A17-Pro gate is removed. Keep iOS 26 minimum (for Liquid Glass per non-negotiable #4) but confirm the intended device floor now that iPhone 13 Pro is an explicit target.

---

## 15. What this amendment does NOT change

- The markdown-brain layer and `b0tBrain` (Phase 1, shipped) — preserved and now *more* central. Everything-is-`.md` is reinforced.
- Privacy non-negotiables: no telemetry, no analytics, no cloud inference, no third-party SDKs that phone home (PRD §2 #2, #3, #5; #5's "no fake heartbeats" intent stands).
- One-time purchase, no subscription, soft-paywall-via-stopped-heart (design doc §7).
- The voice-and-copy guide and its disciplined application (with the §11 "Built with Llama" exemption noted).
- ADR-0003 (SpriteKit + SwiftUI), the ~8-mood-state system, the motion-vocabulary library, and the manifest-driven, agent-editable architecture.
- MCP for Tools (2026-05-04 §2.5) — unchanged; still in v1 scope.
- The configurable-heartbeat *scheduler/proactive loop* (design doc §2.2) — only the unlock-currency role is deferred (§4).
- The anatomical-GUI concept, energy wiring, and organ model (design doc §2.3, ADR-0010) — extended, not replaced.

---

## 16. Mechanical migration

A grep pass surfaces most of the engine-swap work:
- `LanguageModelSession`, `@Generable`, `FoundationModels`, `TickDecision`, `ContextAssembler` token-budget constants → engine abstraction (§2).
- `Gamelabs`, `Hilfer`, placeholder Part atlases → superseded for v1 by piiixl assets (§10).
- `FaceCreator`, `Gallery` (app source groups, plans) → v2 (§4).
- `4096` / `3500` token literals → variable, model-derived (§7/§8).
- Warm-amber `LCDPalette` constant → semantic backlight palette (§9).

After migration, confirm: project builds, `b0tBrain` tests still green (should be untouched), and the engine abstraction has its own tests before any model integration lands.

---

*end of amendment.*
