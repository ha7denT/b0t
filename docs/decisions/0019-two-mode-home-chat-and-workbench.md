# 0019 — Two-mode home screen: chat & workbench, face as the toggle, constant gear

**Status:** Accepted
**Date:** 2026-06-21
**Deciders:** Hayden
**Source:** Brainstorm session 2026-06-21 (visual companion), resolving the "lower-section tabs" open question in `docs/IMPLEMENTATION.md`.
**Supersedes (in part):** design document §2.3's three-register framing — "chat ↔ inspect ↔ edit are register changes within the same screen" and "tap face → focus mode (face zooms, chat compresses)."
**Related:** [`home-screen-two-mode-navigation.md`](../specs/home-screen-two-mode-navigation.md) (the detailed design), [ADR-0017](0017-organ-ring-arrangement.md) (organ ring), [ADR-0016](0016-aesthetic-reconciliation.md) (aesthetic), [ADR-0014](0014-speech-via-illuminated-grille.md) (grille).

## Context

The GUI revision (`import-anatomy-assets`) built the ten-organ anatomy, the painterly face + grille, and the semantic-palette chrome, but left the lower section's navigation undecided — recorded as the "lower-section tabs" blocker in the session handoff. The design document framed the home screen as **three peer registers** (chat / inspect / edit) with a "tap face → focus mode" gesture that *enlarges* the face to focus the conversation. That framing never resolved into a concrete navigation model, and the "focus zoom" gesture conflicts with the natural reading that a large, organ-ringed face means *working on* the b0t rather than *talking to* it.

## Decision

The home screen has **two top-level modes**, not three registers:

- **chat** — face small and centred near the top; the conversation feed takes most of the screen; composer at the bottom; **no organs**.
- **workbench** — face large and surrounded by the ten-organ ring; the **tabbed inspector** occupies the lower half.

Three sub-decisions:

1. **The face is the mode toggle.** Tapping the face switches chat ⇄ workbench in both directions — the single, consistent gesture. Large face = work *on* the b0t; small face = talk *to* it. There is no separate mode button or tab bar.
2. **The gear is constant.** A configuration gear is fixed at the **top-right of the screen in both modes**, independent of the divider and the active mode. It opens app/device configuration, distinct from per-organ controls (which live in the inspector).
3. **The inspector's zero-state is recent chat.** In workbench with no organ selected, the inspector shows the **latest chat snippet** (tapping it returns to chat mode). Selecting an organ replaces the zero-state with that organ's declared tabs (controls · directory · .md, per `anatomical-gui-and-inspector.md` §3); editing a `.md` expands the existing full-screen editor.

"Inspect" is therefore not a peer register — it is **workbench-with-an-organ-selected** — and full-screen `.md` editing is a **sub-state of workbench**.

## Rationale

- **Two modes match the two real verbs.** A user either talks to the b0t or shapes it. Collapsing three registers to two removes a distinction users never needed to track.
- **The face is the honest switch.** "The character is the interface" (design §2.3); making the face itself the toggle, and scaling it to signal which mode you're in, keeps the character central and avoids extra chrome.
- **The inverse-zoom is more intuitive.** A large, organ-ringed face reads as the workbench (you can see and touch its anatomy); a small face reads as a conversational header. This is the opposite of design §2.3's "focus zoom," and is the better mapping — hence the supersession.
- **Recent-chat zero-state keeps workbench tethered to the conversation,** so moving to workbench never feels like leaving the dialogue, and gives a content-level route back to chat.

## Consequences

- **Design document §2.3** gets a "superseded in part by 0019" reconciliation: the three-register prose and the "tap face → focus mode (face zooms, chat compresses)" gesture are replaced by the two-mode model (face *small* in chat, *large* in workbench). The "tap organ → .md content in the lower half" line survives, re-read as a workbench-internal action.
- **`anatomical-gui-and-inspector.md` §5's** "not yet designed: focus/chat states" item is resolved by this ADR and its spec.
- **Implementation is mostly additive** to the Phase-4 / GUI-revision code: workbench ≈ the existing `HomeView` anatomy + inspector; full-screen edit ≈ the existing `EditorView`. Net-new: the chat-mode layout, the face-tap mode toggle, the inspector's recent-chat zero-state (wired from `ConversationManager`), and the constant top-right gear.
- **Still open (parked in the spec §6):** the contents of the configuration surface, the chat ⇄ workbench transition motion, whether the chat-mode heart is tappable, and first-run entry. None block the core navigation build.

## When to revisit

If v2's multi-b0t roster or modular face introduces a third top-level surface (e.g. a Gallery), the two-mode model may need a third mode — but the face-as-toggle and constant-gear conventions are expected to hold.
