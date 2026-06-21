# 0012 — Inference is engine-agnostic; Foundation Models default-when-available, downloadable open-weight otherwise

**Status:** Accepted
**Date:** 2026-05-30
**Deciders:** Hayden
**Supersedes:** the Foundation-Models-*exclusivity* clause of ADR-0001 (the on-device / no-cloud principle stands). Amends PRD §2 non-negotiable #1.
**Source:** amendment 2026-05-29 §2; §14 Q5 resolved 2026-05-30.

## Context

ADR-0001 locked "v1 uses Apple Foundation Models exclusively." The Foundation Models framework requires A17 Pro hardware (iPhone 15 Pro or newer), excluding a large installed base — including Hayden's own iPhone 13 Pro (A15). Tying the product to FM hardware contradicts the reach the tool-first positioning (amendment §1) now demands, and weakens the ownership thesis for everyone who can't run FM.

The amendment as written proposed *replacing* FM with downloadable open-weight models. The design session refined this: rather than drop FM, make inference **engine-agnostic** and let device capability pick the default.

## Decision

Inference is fully on-device and **engine-agnostic**, mediated by an `InferenceEngine` protocol with multiple conformers:

- **Apple Foundation Models** is a first-class conformer, **pre-selected as the default when `SystemLanguageModel.default.isAvailable`** (A17 Pro+ devices). Zero download, works out of the box.
- **A llama.cpp-backed conformer** runs downloadable GGUF open-weight models — the default on non-FM devices, and **switchable on every device**, so even FM-capable users can choose and own a downloadable brain.
- The catalogue offers **FM + three downloadable models** (proposed: Qwen3 1.7B default, Llama 3.2 1B opt-in, + a third pending on-device validation). Per-model license/disclosure surfaces in the Processor organ inspector.

**No cloud inference. No telemetry. Inference is always local** — ADR-0001's spine is reaffirmed, not weakened.

The shipped Phase 2 FM code (`LanguageModelSession`, `@Generable` decisions, `ContextAssembler`) is **wrapped behind the protocol as the FM conformer, not torn out.**

## Rationale

- **Reach + ownership.** FM users get a frictionless default; everyone else (and anyone who prefers it) downloads and owns the brain. The "you own your b0t" thesis is *strengthened* — the engine itself becomes user-chosen.
- **llama.cpp solves two problems with one library.** GGUF metadata carries each model's own chat template (the §3 format layer follows the weights on model switch — no per-model prompt-syntax hand-coding), and GBNF grammar support gives structured output without `@Generable`.
- **Less destructive than a teardown.** Keeping FM as a conformer preserves the shipped, tested Phase 2 loop.

## Consequences

- **PRD non-negotiable #1 is amended** to "inference is on-device and engine-agnostic; FM default-when-available, downloadable open-weight otherwise; no cloud." ADR-0001 gets a "partially superseded" header; its on-device/no-cloud decision stands.
- **Structured-output parity is the meatiest rework.** `@Generable` is FM-only. The llama.cpp conformer must produce the same typed structs (`TickDecision`, `ConversationResponse`, etc.) via GBNF / JSON-schema decoding. The protocol contract is "decode to this `Codable` shape"; each engine satisfies it its own way.
- **Context window is variable, model-derived.** The hardcoded `ContextAssembler` budget (`3500`) and the doc-level `4096` are re-based on the active engine's actual context length. Token metering (amendment §8) gains a real per-model denominator.
- **Two new subsystems:** a resumable, storage/RAM-aware, background-capable **download manager** (pinned source), and a **model lifecycle** (load/unload under iOS jetsam limits; ~2–3GB resident ceiling on 6GB devices caps the catalogue at ~1–2B quantised models).
- **Privacy posture nuance:** the download manager makes the **first sanctioned outbound network call** in the app (model weights). The privacy convention becomes "no network calls except user-initiated model downloads from a pinned, declared source." Privacy manifest + the llama.cpp dependency need an explicit network audit. FM-default users may never trigger a network call.
- **Device floor:** iOS 26 (Liquid Glass, PRD #4) **+ 6GB RAM** (excludes 4GB-class iPhone 11 / SE2/SE3; iPhone 13 Pro supported). See §14 Q9.
- **Phase 2 re-opens** as "inference engine abstraction + llama.cpp + download/lifecycle" — a separate, separately-approved implementation effort. `b0tBrain` is untouched.
- **Docs to use as source of truth:** llama.cpp + GGUF docs for the downloadable path; Apple Foundation Models docs still govern the FM conformer. (PRD §10.5/§13 updated.)

## When to revisit

If a single engine proves clearly sufficient across the whole device floor, the abstraction could collapse — but the multi-engine shape is what delivers both reach and user-owned brains, so this is unlikely pre-v2. Adding *cloud* inference remains the one-way door ADR-0001 named; this decision does not open it.
