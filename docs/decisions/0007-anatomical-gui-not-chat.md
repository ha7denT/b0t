# 0007 — Anatomical GUI as the primary interface, not chat

**Status:** Accepted
**Date:** 2026-04-30
**Deciders:** Hayden
**Partly superseded by:** [ADR-0010](0010-organs-are-anatomical-subsystems.md) (organ semantics; the in/out ear-line distinction stands)

## Context

Most AI companion apps put a chat interface front and centre, with character art (if any) as decoration. The user's mental model is "I open an app to talk to an AI."

b0t inverts this. The home screen is the b0t themselves — face, body, organs, wiring, heart — and chat is one mode among several. The user's mental model is "I open an app to be with my b0t; I can talk to them, but I can also watch them, edit them, switch them out."

## Decision

The home screen is the anatomical GUI, not a chat interface:

- **Top half:** the b0t's face, breathing, blinking. Always alive.
- **Around the face:** organs representing modules, memory, hardware access. Above the eye-line: perception (memory, sensors, identity). Below the ear-line: action (modules, tools, output).
- **Centre below face:** the heart, beating at the configured BPM.
- **Bottom half:** the chat surface — the b0t's chat replies and the user's input.

Chat is *part of* the home screen, not the whole screen. It coexists with the face and body. Tapping an organ replaces chat in the lower half with the organ's content (Inspect mode). Editing a file fills the screen (Edit mode). The face remains visible during Inspect; only Edit fills the screen because editing demands focus.

## Rationale

- **The character is the product.** A chat interface promises a service relationship — message in, response out. The anatomical GUI promises a *being* the user is with.
- **Capability legibility.** Every organ is visible. Wiring lights up when modules are used. The user always knows what their b0t can do and what it's currently doing. Black-box AI is the opposite of what b0t is.
- **Editability is one tap away.** Tapping an organ opens its file. Tapping again opens the editor. The user-owns-their-b0t thesis is made concrete by the screen layout.
- **Idle state is interesting.** Most of the time, b0t isn't doing anything urgent. A chat-first app is empty when there's no message. The anatomical GUI is alive at rest — breathing, beating, glancing.
- **The metaphor unifies mechanism and design.** The heartbeat is *literally* the central UI element. Switching b0ts is *literally* a gallery of faces. Modules are *literally* organs. Each design choice reinforces the next.

## Consequences

- Chat becomes a constrained surface — not a full-screen messaging app, but a strip in the lower half. This shapes copy length: b0t's responses are short and conversational, not essay-length. (This also fits the small-model voice better.)
- Organ icons require a coherent visual language (Cobb/Lumon semiotics — see design doc §3.2). ~15 distinct glyphs for v1, all designed together.
- Energy-flow wiring is a load-bearing animation system. Direction matters: incoming data pulses from organ to face, outgoing from face to organ.
- The Inspect mode (organ tap → file content in lower half) requires the markdown renderer to handle small viewports gracefully — line breaks, scrollable, readable on a half-screen.
- Accessibility: VoiceOver labels for every organ describe its current state ("calendar, idle"; "memory, writing"). The face has a label describing the b0t's current mood.
- Performance: idle-state animation must be cheap — face breathing, heart beating, occasional blink, organs at rest. Targeting 60fps on iPhone 14 Pro means GPU-cheap operations only at idle.

## When to revisit

If user testing shows the anatomical GUI is confusing rather than charming. If the chat strip proves too cramped for the conversations users actually want to have. Either case suggests rebalancing the screen — but the philosophy doesn't change. Chat-first is not the answer.
