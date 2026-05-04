# 0005 — Three-file identity split (core, principles, about_b0t)

**Status:** Accepted
**Date:** 2026-04-30
**Deciders:** Jamee

## Context

A b0t's identity originally lived in a single `identity/core.md` containing voice, behavioural rules, safety stance, and exposition about how the system works. That file ran ~800 tokens. Loaded into context every heartbeat, it consumed a meaningful slice of the 4096-token Foundation Models budget.

Two pressures pulled in opposite directions:

- **Voice consistency** is best preserved by rich prose modelled in the system prompt — the model pattern-matches the *style* of its instructions, not just the *content*. Compressing the prose flattens the b0t's voice.
- **Token economics** demand minimal always-loaded context to leave room for modules, recent journal, and conversation.

## Decision

Identity is split across three files with distinct loading behaviour:

- **`identity/core.md`** — voice anchor and behavioural defaults. Always loaded. Target ~250 tokens. Modelled in characteristic prose to anchor the b0t's voice. Mutable.
- **`identity/principles.md`** — safety contract. Always loaded. Target ~200 tokens. Hard rules that hold regardless of how the user has shaped `core.md`: not pretending to be sentient, not making decisions, no hidden state, respecting user edits. Marked `mutable: false` (GUI does not surface for editing, file is still readable).
- **`identity/about_b0t.md`** — the manual. **Loaded on demand only**, via tool call when the user asks meta questions about how b0t works. Target ~700 tokens. Written in b0t's voice. Contains exposition about file structure, memory architecture, what can be edited.

## Rationale

- **Voice doesn't need length, it needs concentration.** A few sentences of characteristic prose anchor voice better than three paragraphs of explanation. The new `core.md` is shorter but voice-denser.
- **Exposition isn't voice training.** The manual content (how heartbeats work, what files exist, how editing works) doesn't need to be in every model call. It only needs to be available when the user asks.
- **Safety stance must be visible to the model in every call.** Splitting principles into a separate file lets us keep them load-bearing without coupling them to voice.
- **Each file has one job.** A user who wants to change voice edits one file. A user who wants to read the manual opens another. The mental model is cleaner — same principle as the anatomical GUI.

## Consequences

- Always-loaded identity drops from ~800 tokens to ~450, freeing ~350 tokens per heartbeat for modules and recent context.
- The `ContextAssembler` must distinguish always-loaded from on-demand files and only fetch on-demand content when the relevant trigger fires (meta question, recall-by-topic, etc.).
- A new tool handle, `recall_about_b0t`, is exposed to the model so it can pull `about_b0t.md` into context when needed.
- Frontmatter on each file declares its loading behaviour explicitly (`always_in_context: true|false`).
- The user-facing implication: the GUI shows three identity organs (or one identity organ with three sub-files visible), not one. The Inspect mode lists them in order.

## When to revisit

If the user research surfaces confusion about which file does what. If voice consistency is failing despite the concentrated `core.md`, suggesting the model needs more priming context (in which case `about_b0t.md` may need partial inclusion — e.g., always-load the "how I think" section).
