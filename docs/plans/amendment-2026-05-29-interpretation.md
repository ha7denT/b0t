# Interpretation plan — amendment 2026-05-29

**Status:** Awaiting Hayden's approval before execution
**Author:** Claude Code (interpretation pass per amendment §0.5)
**Source:** `docs/b0t-amendment-2026-05-29.md`
**Decisions folded in:** §14 Q3/Q4/Q5/Q6/Q7/Q9 resolved in the 2026-05-30 session (below). Q1/Q2/Q8 deferred.

This is the "produce a plan, not code" deliverable the amendment's §0.5 requires. It lists what changes, which ADRs supersede which, which shipped code is affected, the phase re-sequence, and the execution order. Nothing below is executed until Hayden approves this document.

---

## 0. §14 decisions made this session (2026-05-30)

| Q | Decision | Notes |
|---|---|---|
| **Q5** | **Engine-agnostic inference. FM is the default *when the device supports it*; llama.cpp-backed downloadable open-weight models otherwise. Switchable on every device.** | This *reshapes* amendment §2 — see §1 below. FM is **not** removed. |
| **Q6** | Catalogue offers **FM + 3 downloadable models**. Per-model license/disclosure shown in the **Processor organ inspector**. Proposed trio: Qwen3 1.7B (default download, Apache-2.0), Llama 3.2 1B (opt-in, "Built with Llama"), + a third — **exact lineup + quant levels pending on-device validation** (RAM fit on A15, context-window differences). | Not silently resolved; flagged as an engineering follow-up. |
| **Q7** | **Minimal TTS in v1** — system `AVSpeechSynthesizer`, no filter chain. Grille uses TTS amplitude envelope. The 8-filter `b0tAudio` chain → v2. | Shrinks Phase 8. |
| **Q9** | **Device floor: iOS 26 + 6GB RAM.** Excludes 4GB-class (iPhone 11 / SE2/SE3). iPhone 13 Pro (A15, 6GB) supported. | iOS 26 stays for Liquid Glass (PRD #4). |
| **Q3** | **Palette overrides "never blue."** yellow `#EAFF3D` / aqua `#3DEAFF` / pink `#FF3DEA` semantic highlights over a muted dark base. | Unblocks aesthetic ADR (colour clauses), design §3.5, b0tDesign tokens. |
| **Q4** | **Single b0t in v1.** Multi-b0t roster + Gallery → v2. | Heartbeat *scheduler* stays; unlock-currency role defers. |

**Deferred (not resolved):**
- **Q1** (face: 1-bit monochrome vs. painterly) and **Q2** (CRT eye-screen vs. all-LCD) — await Hayden's incoming UI layout designs. They gate the *face-register* clauses of the aesthetic ADR (ADR-0016), which is authored only after Q1/Q2/Q3 are all confirmed (amendment §13).
- **Q8** (trial length 3 vs 7 days) — pre-launch pricing call, blocks nothing.

---

## 1. How the engine decision reshapes amendment §2

The amendment as written reverses non-negotiable #1 and removes Foundation Models. Hayden's Q5 answer changes this to a **multi-engine, capability-detected architecture**:

- An **`InferenceEngine` protocol** (the amendment's *recommended* abstraction) becomes **mandatory and central**.
- **FM is a first-class conformer**, pre-selected as the default *when `SystemLanguageModel.default.isAvailable`*.
- **A llama.cpp-backed conformer** serves downloadable GGUF open-weight models — the default on non-FM devices, and selectable everywhere.
- The shipped Phase 2 FM code (`LanguageModelSession`, `@Generable` decisions, `ContextAssembler`) is **wrapped behind the protocol, not torn out.**

**Consequences for the docs:** PRD non-negotiable #1 is *amended* ("inference is on-device and engine-agnostic; FM default-when-available, downloadable open-weight otherwise; no cloud"), **not reversed**. ADR-0001's on-device/no-cloud principle **stands**; only its "Apple FM exclusively" clause is superseded.

**The hard engineering problem (own ADR note):** `@Generable` is FM-only. The llama.cpp conformer must produce the *same* typed structs (`TickDecision`, `ConversationResponse`, etc.) via grammar-constrained decoding (GBNF) or JSON-schema decoding. The protocol contract is "decode to this `Codable` shape"; each engine satisfies it its own way. This is the meatiest part of the Phase 2 re-open.

**Why llama.cpp:** GGUF metadata carries the model's own chat template (solves Hayden's "each model needs specific prompt syntax" — the §3 format layer follows the weights on model switch) *and* supports GBNF grammars (solves the `@Generable`-parity problem). One library, both problems.

---

## 2. Discrepancies found between the amendment and the shipped code

Verified against the codebase 2026-05-30. These adjust effort estimates and correct framing the new ADRs must not inherit.

1. **§5's "MoodController, SKAction sequences, motion-vocabulary library all stand" is inaccurate — none are shipped.** Phase 4 shipped *static* parts. Mood today is only the `MoodTag` enum in `b0tCore/Decisions`. There is no MoodController, no face SKAction sequences, no motion library — they were always Phase 6 (unstarted). So §5's framing ("they now *select* a pre-rendered animation rather than animating composited parts") describes **net-new work against a new target**, not preservation. ADR-0013 must say so to avoid under-budgeting Phase 6.
2. **The token budget is one code constant, not "3500/4096."** `ContextAssembler.swift:36` hardcodes `limit = 3500`. `4096` lives only in docs (design §5.2, PRD §3.4, ADR-0001 consequences). Code migration = one literal → variable, model-derived; the rest is doc rebasing.
3. **The inspector is not yet tabbed.** `InspectionPanel` switches over **9 organ types** with bespoke per-organ views (`DirectoryNavigatorView`, `OrganInspectionView`, `HeartInspectionContainer`). "Up to three tabs, render only what an organ declares" (§6) is a **new uniform abstraction** over those paths — a moderate refactor, not a small extension.
4. **The catalogue already carries the v2-modular fields.** `BotModel` has `parts {skull,eyes,jaw}`, `decals`, `palette`, `heartbeatUnlockThreshold`. So §5's "preserve manifest shape, populate one pre-composed unit" is clean — those fields become v2-deferred; §7's `slot` field is the only net-new addition.

---

## 3. Privacy posture genuinely shifts (amendment §11 under-states this)

The **download manager makes the first sanctioned outbound network call in the app's history** (fetching model weights, hundreds of MB to >1GB). Inference stays local, but:
- The "no new network calls" convention (CLAUDE.md) and non-negotiable framing must become **"no network calls except user-initiated model downloads from a pinned, declared source."**
- The App Store privacy manifest and the new dependency (llama.cpp + downloader) need an **explicit network audit**.
- FM-default-on-capable-devices means an FM user may **never** trigger a network call; the privacy story holds for both paths but must be stated for both.

This is defensible and on-thesis (the user chooses and downloads the brain), but it edits a non-negotiable's framing, so it is surfaced rather than absorbed.

---

## 4. ADRs to author (append-only; supersede, don't edit history)

| New ADR | Title | Supersession |
|---|---|---|
| **0012** | Inference is engine-agnostic; FM default-when-available, llama.cpp downloadable, switchable everywhere | Supersedes the **FM-exclusivity clause** of ADR-0001 (on-device/no-cloud principle stands). Amends PRD #1. |
| **0013** | v1 ships a single non-modular b0t (one sprite-sheet face, no gallery); modular Parts/Manufacturers/Models/Face Creator/Gallery/heartbeat-unlock → v2 | Supersedes/extends ADR-0011; **partially supersedes ADR-0008** (Gamelabs baked palettes, gallery cap-6, heartbeat-unlock currency, manufacturers-as-content → v2). |
| **0014** | Speech signalled by illuminated speaker grille; no moving jaw in v1 | New. References the mood-×-mouth combinatorial rationale. |
| **0015** | Content/format boundary; slot-based prompt assembly | New. Documents the §3/§7 architecture. |
| **0016** | Aesthetic reconciliation — LCD-forward, semantic palette, "never blue" overridden | New. **Authored after Q1/Q2 settle via incoming UI designs.** Palette-override clause already decided (Q3). |

**Header lines to add to historical ADRs** (no decision-body edits):
- ADR-0001: "Partially superseded by 0012 — FM-exclusivity clause only; on-device/no-cloud principle stands."
- ADR-0011: "Superseded by 0013."
- ADR-0008: "Partially superseded by 0012/0013 — v1 scope; retained as the v2 design."

---

## 5. Documents to revise

Refines amendment §12 with the §14 decisions folded in. **"Edit now" = unblocked; "after designs" = waits on Q1/Q2.**

| Target | Sections | Change | When |
|---|---|---|---|
| `README.md` | intro, Status | Replace "Foundation Models framework animates those files" + "3B-parameter local model" → engine-agnostic (FM default-when-available / downloadable otherwise). Phase 2 re-opened. Tool-first one-liner. | Now |
| `CLAUDE.md` | Philosophy ¶, Conventions, DoD, module tree | Replace FM-only claim; tool-first positioning; privacy convention → "no network calls except user-initiated model downloads"; add `b0tHome/` to module tree. Aesthetic clause → reference §9 reconciliation (colour now; face register after designs). | Now (aesthetic face clause: after designs) |
| `design_document.md` | §1, §1.3 | Tool-first thesis; "productivity tool with a face" moves out of *what b0t is not*. Handle the "you own the brain" wrinkle for FM vs downloadable users. | Now |
| `design_document.md` | §1.1, §2.2, §5.2 | Replace FM-as-the-engine prose with engine-agnostic; re-base the 4096-token memory architecture on **variable, model-derived** context windows. | Now |
| `design_document.md` | §2.4, §2.5, §10 | Move multi-b0t/gallery + Face Creator (parts/decals/palettes) to v2. v1 = single b0t, single face. | Now |
| `design_document.md` | §3.5 | Colour rule: "never blue / warm phosphor" → yellow/aqua/pink semantic system over muted dark. | Now |
| `design_document.md` | §3.3, §3.6 | Face register (pixel-art-painterly vs 1-bit) + CRT/bloom transitions vs LCD-no-bloom. | **After designs (Q1/Q2)** |
| `prd.md` | §1, §2 #1 | Tool-first summary; amend non-negotiable #1 to engine-agnostic on-device. | Now |
| `prd.md` | §2 #8 | Soften to single-b0t for v1. | Now |
| `prd.md` | §3.2, §3.3, §3.4 | Rewrite FM session pattern + data flow as engine-agnostic; re-base token budgeting on variable window. Add download/lifecycle subsystems. | Now |
| `prd.md` | §3.6, §7 | Privacy: declare the model-download network call + pinned source; privacy-manifest note. | Now |
| `prd.md` | §10.5, §13 | Replace "Apple Foundation Models docs as source of truth" → llama.cpp + chosen-runtime docs (FM docs still apply to the FM engine). | Now |
| `prd.md` | §12 Q4 | Re-open + re-answer: piiixl 1-bit packs + single face for v1; Gamelabs → v2. | Now |
| `prd.md` | §5.4, §5.5 | §5.4: single sprite-sheet face + grille, no jaw. §5.5: minimal TTS (no filter chain) for v1. | Now (face visual: after designs) |
| `b0t-amendment-2026-05-04.md` | §2.1–2.4, §3.1–3.3 | Mark "v2 — deferred 2026-05-29." Do not delete; it is the v2 design. | Now |
| `docs/IMPLEMENTATION.md` | ledger, current state, open questions | Re-open Phase 2 (engine abstraction + llama.cpp + download/lifecycle); re-scope Phase 6 (single sprite-sheet face, not Face Creator) and Phase 7 (→ v2); record this amendment + the resolved/deferred §14 items. | Now |

---

## 6. Code impact (refines amendment §16)

**Edit during the Phase 2 re-open (not in this doc pass):**
- Introduce `InferenceEngine` protocol in `b0tCore`. Make `LiveLanguageModelClient` the **FM conformer**. Add a **llama.cpp conformer**.
- Structured output: keep `@Generable` for the FM path; add GBNF/JSON-schema decoding to the same typed structs for the llama.cpp path.
- `ContextAssembler.swift:36` `limit = 3500` → variable, derived from the active engine's context window.
- Capability-based default selection (the `SystemLanguageModel.default.isAvailable` check already exists; route to a real fallback engine instead of a stub).
- **New subsystems:** download manager (resumable, storage/RAM-aware, background-capable, pinned source) + model lifecycle (load/unload under jetsam).
- `b0tBrain` catalogue: add `slot` field (§7); mark `parts`/`decals`/`palette`/`heartbeatUnlockThreshold` v2-deferred; add a single pre-composed face-unit entry.
- `b0tFace`: single-unit sprite-sheet face + illuminated grille node; jaw motion dropped. (MoodController/SKAction/motion-library = net-new Phase 6, not preserved.)
- `b0tHome`: tabbed inspector abstraction (Controls / Directory / `.md`), render-declared-tabs; Processor organ inspector (model switch, params, install/download, storage, per-model disclosure, read-only chat template).
- `b0tDesign`: add yellow/aqua/pink semantic tokens; 1-bit mask runtime-tint utility; re-colour `LCDPalette` to semantic backlights (face/eye-screen colour treatment waits on Q1/Q2).
- Token metering: per-organ + per-`.md` token subtotals against the model's context-window denominator; recompute on content change / model swap; tokenizer-specific.

**Verify after migration:** project builds; `b0tBrain` tests untouched/green; the engine abstraction has its own tests before any model integration lands.

---

## 7. Phase ledger re-sequence

| # | Phase | Change |
|---|---|---|
| 2 | Foundation Models loop | **Re-opened** → "Inference engine abstraction + llama.cpp + model download/lifecycle." FM code retained as one conformer. |
| 5 | Onboarding | Stays deferred; re-evaluate beats once single-b0t/engine reality settles (still references unbuilt features). |
| 6 | Face rig + Parts + Face Creator | **Re-scoped** → "Single sprite-sheet face rig + grille." Parts library + Face Creator → v2. |
| 7 | Multi-b0t + Gallery | **→ v2.** Removed from v1 ledger. |
| 8 | Audio | **Shrunk** → minimal TTS (no filter chain) + UI sounds. 8-filter chain → v2. |

---

## 8. Execution order (once approved)

1. **ADRs first** (0012–0015 now; 0016 after UI designs) + header lines on 0001/0008/0011. ADRs are the settled-decision record everything else cites.
2. **`b0t-amendment-2026-05-04.md`** v2-deferral header lines.
3. **Core docs** (README, CLAUDE.md, design_document, prd) — "edit now" rows in §5.
4. **`IMPLEMENTATION.md`** ledger + amendment record.
5. **Re-pose Q1/Q2** when Hayden's UI designs arrive → author ADR-0016 + the "after designs" doc rows.
6. **Code** (Phase 2 re-open) is a *separate* implementation effort with its own plan — not part of this doc pass.

This pass produces **docs + ADRs only**. No code is touched until the Phase 2 re-open is planned and approved separately.
