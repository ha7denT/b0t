# Home-screen navigation — two modes: chat & workbench

**Status:** Design of record (ASCII-fidelity) for the GUI revision's navigation model; feeds the layout/inspector implementation on `import-anatomy-assets`.
**Date:** 2026-06-21
**Deciders:** Hayden
**Source:** Brainstorm session 2026-06-21 (visual companion), resolving the "lower-section tabs" open question from `docs/IMPLEMENTATION.md`.
**Related:** [`anatomical-gui-and-inspector.md`](anatomical-gui-and-inspector.md) (organ ring, inspector, asset mapping — this note supplies the navigation model that spec marked "not yet designed" in §5), [ADR-0017](../decisions/0017-organ-ring-arrangement.md) (ten organs), [ADR-0016](../decisions/0016-aesthetic-reconciliation.md) (aesthetic), [ADR-0014](../decisions/0014-speech-via-illuminated-grille.md) (grille).
**Supersedes:** design document §2.3's three-register framing ("chat ↔ inspect ↔ edit" + "tap face → focus mode (face zooms, chat compresses)"). An ADR recording this supersession is a follow-up (see §7).

Fidelity is ASCII/structural by intent; pixel-true rendering is deferred to implementation. The accepted wireframes live at `.superpowers/brainstorm/.../two-modes-v2.html`.

---

## 1. The model: two modes, not three registers

The home screen has **two top-level modes**, switched by **tapping the face**:

- **chat** — talking *to* the b0t. The face is small and centred near the top; the conversation feed takes most of the screen; a composer sits at the bottom. No organs.
- **workbench** — working *on* the b0t. The face is large and surrounded by the ten-organ ring (processor crown + meters, left/right columns, heart); the **tabbed inspector** occupies the lower half.

The earlier docs framed three peer registers (chat / inspect / edit). This note collapses that: **"inspect" is just workbench-with-an-organ-selected, and full-screen `.md` editing is a sub-state of workbench.** Two modes is the whole top-level model.

```
        CHAT MODE                         WORKBENCH MODE
  ┌───────────────────┐             ┌───────────────────┐
  │              ⚙ cfg │             │ ▦ processor  ⚙ cfg│  ← gear constant top-right (both)
  │      ╭─────╮       │             │     ▮in  ▮out      │
  │      │ ◉ ◉ │       │  small,     │  ◯─┐ ╭─────╮ ┌─◯   │  large face
  │      ╰──▬──╯       │  centred    │  ◯─┤ │ ◉ ◉ │ ├─◯   │  + 10 organs
  │     b0t-01 · ♥     │  face       │  ◯─┤ ╰──▬──╯ ├─◯   │
  │  tap face→workbench│             │  ◯─┘   ♥    └─◯    │
  │ ───────────────────│             │ ╱────────────╱     │  ← divider
  │  ▸ chat feed        │            │ ┌─[recent·…]─────┐ │  ← tabbed inspector
  │    (most of screen) │            │ │ latest chat snip│ │     (default: recent chat)
  │ ───────────────────│             │ └─────────────────┘ │
  │  message b0t…       │            └───────────────────┘
  └───────────────────┘
```

## 2. The mode toggle

- **Tap the face** toggles chat ⇄ workbench, both directions. It is the single, consistent gesture. (Rationale: the face is already the natural "go to the b0t" target; big face = work on it, small face = talk to it.)
- A **second route back to chat** exists from inside the inspector's default state: tapping the **recent-chat snippet** returns to chat mode (see §4). This gives a content-level affordance, not just the face.
- No dedicated mode button or tab bar — the face *is* the switch.

## 3. The constant gear (configuration)

- A **settings gear is fixed at the top-right of the screen in both modes** (labelled `config`). It does not move with the divider or the mode.
- It opens the app/device **configuration** surface (distinct from per-organ controls, which live in the inspector). The *contents* of configuration are out of scope for this note — see §6.

## 4. The inspector (workbench lower half)

The lower half in workbench is the **tabbed inspector**. Its tab set is **contextual**:

- **No organ selected (zero-state) → "recent":** the inspector shows the **latest chat snippet** (last turn or two). Header reads e.g. `▸ no organ selected — latest chat`. Tapping the snippet returns to chat mode. This keeps workbench tethered to the conversation.
- **Organ selected → that organ's tabs:** the strip becomes the organ's declared tabs — up to **controls · directory · .md** — exactly as specified in `anatomical-gui-and-inspector.md` §3 (rendered only if declared; the heart has one). Selecting an organ replaces the "recent" zero-state with the organ's tab set; deselecting (close ✕) returns to "recent".
- **Editing a `.md` → full screen:** opening a file's `.md` for edit expands the existing full-screen `EditorView`; dismissing returns to the inspector. Editing is the only thing that leaves the home layout.

Panel backlight stays the organ's semantic colour (aqua functional / yellow tokens / pink heart), per the GUI spec.

## 5. State model

Two pieces of view state drive the home screen:

- `mode: .chat | .workbench` — toggled by the face tap (and the recent-snippet tap, which forces `.chat`).
- `inspectorSelection: .recentChat | .organ(OrganID)` — only meaningful in `.workbench`; defaults to `.recentChat`; set by organ taps, cleared by the inspector close control.

Full-screen edit remains a separate presentation (`.fullScreenCover`, as built) layered over `.workbench`.

## 6. Open / deferred (not resolved here)

- **Configuration contents.** What the gear opens (device prefs, TTS, trial/IAP entry, about) is undesigned. Parked.
- **Chat-mode organ access.** Confirmed: organs are **workbench-only** — chat mode shows none. (If a future need arises to surface, say, the heart in chat, revisit.)
- **Transition motion.** The chat ⇄ workbench animation (face scale/translate, feed↔anatomy crossfade) is a polish pass; design §3.6 "register shift / backlight settling" idiom applies. Not specified frame-by-frame here.
- **First-run / onboarding** entry into these modes — still deferred with Phase 5.
- **Chat-mode heart/BPM affordance.** The `♥` shown beside `b0t-01` in chat is decorative here; whether it's tappable (jump to heart config, which lives in workbench) is open.

## 7. Consequences (doc drift to reconcile)

- **Design document §2.3** — the "chat ↔ inspect ↔ edit" three-register prose and "tap face → focus mode (face zooms, chat compresses)" are **superseded** by the two-mode model (face is *small* in chat, *large* in workbench — the inverse). Update §2.3; the "tap organ → .md replaces chat" line is preserved but now reads as a workbench-internal action.
- **`anatomical-gui-and-inspector.md` §5** — its "not yet designed: focus/chat states" line is now answered by this note; cross-link it.
- **New ADR (follow-up)** — author an ADR ("two-mode home screen: chat & workbench, face-toggle, constant gear") recording the supersession of design §2.3, mirroring how ADR-0016/0017 captured the other GUI decisions.
- **`docs/IMPLEMENTATION.md`** — the SESSION HANDOFF "lower-section tabs UNRESOLVED" blocker is now resolved by this note; update the handoff.
- **Implementation is mostly additive** to the Phase-4 / GUI-revision code: workbench ≈ the existing `HomeView` anatomy + inspector; full-screen edit ≈ the existing `EditorView`. Net-new: chat-mode layout, the face-tap mode toggle, the inspector's `.recentChat` zero-state (wired from `ConversationManager`), and the constant top-right gear.
