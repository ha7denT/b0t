# 0015 — Content/format boundary; slot-based prompt assembly

**Status:** Accepted
**Date:** 2026-05-30
**Deciders:** Hayden
**Source:** amendment 2026-05-29 §3, §7; depends on ADR-0012 (multi-engine).

## Context

With multiple inference engines (ADR-0012), the same b0t content must be wrapped into different exact token sequences — Llama's `<|start_header_id|>…<|eot_id|>`, Qwen's ChatML `<|im_start|>…<|im_end|>`, FM's own format. Conflating "what the b0t says" with "how a given model expects it wrapped" would either lock content to one model or push tokenizer-specific detail into user-editable markdown, where a wrong template degrades output silently with no error. The shipped `ContextAssembler` is FM-shaped (it assumes one format).

## Decision

Two layers, cleanly separated:

- **Content layer — model-agnostic, organ-owned, user-authored.** What the organs produce: identity/personality, heartbeat instructions, memory, module specs. Plain markdown. This is the existing markdown-brain layer.
- **Format layer — model-specific, engine-owned, not user-edited.** How assembled content is wrapped into the exact token sequence a model expects (chat template, special tokens). **Driven by the runtime through its messages/chat-completion API**, letting the engine apply the model's *own* embedded template (GGUF metadata carries it for the llama.cpp path; FM applies its own). The format follows the weights automatically on model switch.

**Prompt assembly is slot-based composition.** Organs are prompt fragments with a UI. Each organ's contribution **declares where it lands** — a `slot` (e.g. `system`, `prepended_context`, `per_turn`, `tool_defs`) — folded into the existing manifest/catalogue contract. `ContextAssembler` becomes: gather declared organ fragments by slot → assemble role-tagged messages → hand to the active engine, which applies the format layer.

**Optional advanced affordance:** expose the chat template **read-only** in the Processor inspector, with a clearly-marked "advanced: override" that warns it can break output.

## Rationale

- **Safe model-switching is nearly free.** Because the format follows the weights, switching engines/models doesn't require re-authoring any organ content.
- **Deterministic without a bespoke templating engine.** Slots make assembly explicit and ordered; role-tagged messages are the universal interface every engine accepts.
- **Per-organ token attribution falls out for free** (amendment §8): each slot fragment has a token subtotal, enabling the per-organ and per-`.md` metering and the context-window gauge.

## Consequences

- The manifest/catalogue contract gains a `slot` field per organ contribution.
- `ContextAssembler` is reworked from FM-shaped concatenation to slot-gather → role-tagged messages. The variable, model-derived context window (ADR-0012) is the budgeting denominator.
- A chat template is **never** modelled as editable organ content; it is engine/tokenizer-owned. The read-only inspector view is the only surface, behind an advanced override.
- Token counts are tokenizer-specific and recomputed on content change or model swap, not per frame; structural/template overhead is included, not just organ content.

## When to revisit

If a future engine can't expose a messages/chat-completion API or embed its template, the format layer would need a per-engine template store. The content/format separation still holds.
