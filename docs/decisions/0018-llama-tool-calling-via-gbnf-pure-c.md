# 0018 — Llama-path tool-calling via GBNF on the pure-C boundary; minja/common not adopted

**Status:** Accepted
**Date:** 2026-06-02
**Deciders:** Hayden
**Relates to:** [ADR-0012](0012-inference-engine-agnostic.md) (engine-agnostic inference); `docs/specs/phase-2-inference-engine-abstraction.md` §6 (tool-calling on the llama path), §8 (staging), §9 Q5 (chat-template constraint).
**Supersedes (in part):** the Phase-2 spec §8 Stage-B note "XCFramework integration (Swift/C++ interop)" — Stage B shipped **pure C, no C++ interop** (`b0tLlama/CLAUDE.md`); this ADR makes that boundary a deliberate, recorded choice rather than an as-built accident.

## Context

§14 Q6 (validate the downloadable model lineup) raised a prerequisite question: how does b0t do **tool-calling on the llama path**? Research into current llama.cpp surfaced that robust native tool-calling uses the model's embedded **Jinja** template via the `minja` engine under `--jinja`, with an autoparser that infers the tool-call format from the template — and that `llama_chat_apply_template` (the pre-defined-family path, no Jinja) is the *degraded fallback*. This appeared to contradict the spec §9 Q5 constraint ("pre-defined template list, not arbitrary Jinja").

We investigated whether the minja/autoparser layer is reachable from our pinned dependency.

**Finding (b9415 xcframework, inspected on disk 2026-06-02):**
- Headers shipped: `llama.h`, `ggml-*.h`, `gguf.h` only. **No** `common.h`, `chat.h`, `minja.hpp`, `chat-template.hpp`.
- Exported symbols: `llama_chat_apply_template`, `llama_chat_builtin_templates`, `llama_model_chat_template`, and the internal predefined-family detector (`llm_chat_apply_template`, `llm_chat_template_from_str`). **Zero** `common_chat_*` / `minja` / `chat_parse` / `tool_call` symbols.
- `llama.h` line 1168, verbatim: *"This function does not use a jinja parser. It only support a pre-defined list of template."*

So minja + the chat-parser autoparser live in llama.cpp's C++ **`common`** library, which the official XCFramework does **not** ship. Reaching it would mean building/vendoring `common` (C++17: `chat.cpp`, `chat-parser.cpp`, `minja.hpp`, deps) into a custom xcframework or source target, enabling C++ interop, and maintaining llama.cpp internals the header marks "avoid using in third-party apps."

## Decision

**Llama-path tool-calling is done with a GBNF-constrained harness on the existing pure-C boundary. We do not adopt minja / llama.cpp's `common` layer in v1.**

Concretely, as the Phase-2 spec §6 already prescribes:
- `LlamaEngine` injects tool descriptors into the prompt and **GBNF-constrains emission to a tool-call grammar**, parses the (grammar-guaranteed well-formed) call, executes via existing `b0tModules` tools, feeds results back, and iterates (bounded). This reuses the GBNF machinery already proven against b9415 in Stage B's structured output.
- `EngineCapabilities.supportsToolLoop` gates it: a model that tool-calls poorly is marked tools-off and degrades to conversation/heartbeat reasoning, said honestly in voice. FM keeps its native tool orchestration unchanged.
- The chat-template handling stays on `llama_model_chat_template` + `llama_chat_apply_template` (predefined-family). The per-model **go/no-go gate is therefore: does the model's GGUF-embedded template get recognized by `llama_chat_apply_template`?** — validated on-device per model (see `docs/specs/phase-2c-q6-model-lineup-validation.md`).

## Rationale

- **The benefit minja buys, we already have.** The autoparser's value is well-formed tool calls. **GBNF guarantees well-formed output by construction** — it structurally eliminates the "small models emit malformed tool calls" failure mode the research flagged, which is *more* reliable than parsing free-form model output, not less. The model's only job is choosing *which* tool and filling args; format is enforced.
- **Preserves the pure-C design principle.** b0tLlama deliberately isolates the binary dependency behind a pure-C `import llama` with no Swift/C++ interop. Adopting `common`/minja means C++17 interop, a hand-maintained shim, a custom xcframework build, and tracking internals upstream marks as not-for-third-parties — a standing maintenance tax.
- **Consistent with the existing spec.** §6 already specified a "GBNF-constrained tool-call loop"; this ADR confirms it against the as-built dependency and records *why* the alternative was declined after investigation.
- **The §9 Q5 "predefined-family, not Jinja" constraint is real for us** — not because llama.cpp can't do Jinja, but because *our pure-C integration* uses the path that can't. The constraint is a consequence of this decision, now made explicit.

## Consequences

- **Catalogue curation is for *decision* competence, not *format* competence.** Model selection (§14 Q6) weighs BFCL/tool-calling scores as a signal of whether the model picks the right tool with the right args; output formatting is GBNF's job. ("Native tool-call handler list" membership in llama.cpp is irrelevant to us — that's a `common`-layer concept.)
- **Template-family fit remains a hard per-model gate**, reframed as "embedded template recognized by `llama_chat_apply_template`." Models whose embedded template isn't detected as a supported family are disqualified (or need a forced known-family override). Validated on-device.
- **Phase-2 spec §8 Stage-B "Swift/C++ interop" note is superseded** by the pure-C as-built; no doc rewrite beyond this ADR's forward-link is required.
- **A tool-call GBNF grammar + bounded loop** is net-new work in the eventual llama tool-call harness (still Q6-gated / post-catalogue), layered on Stage B's grammar infrastructure.
- No change to the FM path, to structured (non-tool) output, or to the download/catalogue/lifecycle mechanism (Stage C3/C4).

## When to revisit

- If llama.cpp ships `common`/minja in its official XCFramework (or a stable C wrapper for the chat-parser appears), re-evaluate adopting native autoparser tool-calling — the GBNF harness would remain a valid, possibly preferred, fallback.
- If GBNF tool-calling proves unreliable in practice at this model scale (the model picks wrong tools/args often despite enforced format), revisit either the model lineup or the harness design — not the format mechanism.
