# 0002 — Markdown files as the source of truth for b0t state

**Status:** Accepted
**Date:** 2026-04-30
**Deciders:** Hayden

## Context

Every AI companion stores user-relevant state somewhere — personality, memory, preferences, history. The choice is between an opaque database (SwiftData / Core Data / SQLite, only readable through the app) and human-readable files (markdown on disk, openable in any editor).

b0t's philosophy is that the user owns their b0t. Ownership without legibility is theatrical. If the user can't see and modify the state, the b0t is a service in disguise.

## Decision

All canonical b0t state — identity, memory, modules, heartbeat configuration, journal — is stored as plain markdown files in the user's Documents directory. No SwiftData, no Core Data, no proprietary serialisation. Files use YAML frontmatter for structured parameters and prose below for behavioural content.

Ephemeral caches (parsed-markdown ASTs, animation state, sprite atlas indices) may use SwiftData but are never the source of truth — they're rebuilt from the markdown at any time.

## Rationale

- **Legibility = ownership.** A user can open `~/Documents/b0ts/b0t-01/identity/core.md` in any text editor and see exactly who their b0t is. That's the product promise made literal.
- **Editability = agency.** Users can modify any aspect of their b0t through a familiar tool (a text editor) without learning a custom UI for every parameter.
- **Portability = permanence.** A b0t can be airdropped, backed up, version-controlled, or migrated to a future b0t app without dependency on our binary format.
- **Transparency = trust.** Combined with the journal, the user can always see what their b0t knows and what it has done. No hidden state.
- **Module marketplace becomes possible (v2).** Plaintext modules can be shared, forked, reviewed.

## Consequences

- File I/O performance matters. Caches are essential. Frequent file reads must be cheap; the brain layer uses `NSCache` with explicit invalidation on write.
- Frontmatter parsing requires a vetted YAML library (CYaml or Yams).
- File-format compatibility is a long-term commitment. Frontmatter keys cannot be silently renamed; old keys must be migrated when changed.
- Lossless round-tripping (load → save with no semantic change) is required, including preserving comments, whitespace, and key ordering where possible.
- Conflict resolution between user edits and b0t edits is a real problem. v1 uses last-write-wins with a pre-edit backup; b0t flags conflicts in conversation rather than silently overwriting.

## When to revisit

If file I/O becomes a measured performance bottleneck. If the file format proves too constraining for a feature we want to ship. Note: revisiting does not mean abandoning markdown — it might mean adding a write-through cache layer or a binary index, while keeping markdown canonical.
