# 0001 — On-device LLM only

**Status:** Accepted
**Date:** 2026-04-30
**Deciders:** Jamee

## Context

b0t needs an LLM to animate the markdown identity, memory, and module files. The choice is between Apple's on-device Foundation Models framework (~3B params, local, free) and a cloud LLM (OpenAI, Anthropic, Google — far more capable but cloud-hosted, paid per call, network-dependent).

A b0t that knows the user's calendar, mail, location, and conversations is most valuable precisely when those signals are also most sensitive. Trusting that data to a cloud service would undermine the core promise.

## Decision

v1 uses Apple Foundation Models exclusively. No cloud LLM fallback. No optional cloud premium tier. No network calls for inference.

## Rationale

- **Privacy is the product.** A user-owned, fully on-device companion is the differentiator no cloud-based competitor can match.
- **Economics flip.** A heartbeat agent firing every 30 minutes against cloud APIs would cost $50–200 per user per month. On-device inference is free, making always-on autonomy viable.
- **Offline reliability.** Heartbeats work on a plane, on the train, with no signal.
- **Permanence.** A cloud LLM tier creates a product whose personality can be deprecated, throttled, or changed by a vendor decision. On-device, the user owns the experience indefinitely.

## Consequences

- The 4096-token context window is the central constraint, shaping the entire memory architecture (see ADR 0005).
- Some categories of capability (long-form creative writing, multi-step reasoning, deep research) are out of reach for v1. b0t is deliberately scoped to *attention, observation, and structured action* — tasks the small model handles well.
- No marketing claim of "smarter than the rest" — b0t competes on yours-not-rented, not on raw capability.

## When to revisit

If Apple ships a substantially more capable on-device model, or if the user research surfaces a concrete capability gap that's blocking adoption, reconsider — but adding cloud is a one-way door for the privacy promise. Re-opening this decision means rewriting the philosophy.
