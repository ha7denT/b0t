# b0tBrain

The markdown layer. Reads, parses, and writes the user's b0t files.

## Public API contracts (target shape)

- `BotLoader` — loads a b0t directory into typed in-memory representations on demand.
- `BotWriter` — persists changes back to disk losslessly.
- `Frontmatter` — YAML parser (use Yams; do not roll our own).
- `MarkdownLink` — resolves `[label](relative/path.md)` and `[[wikilink]]` references.
- `BacklinkIndex` — computes which files reference a given file.

## Patterns

- **Lossless round-trip is REQUIRED.** Load → save preserves whitespace, comments, and frontmatter key order. See PRD §5.1.
- No permanent in-memory model. Files read on demand, cached via `NSCache` with explicit invalidation on write.
- Default b0t files ship in the app bundle at `default-bot/...`; user b0ts live in `~/Documents/b0ts/...`.

## Read first when working here

- `docs/prd.md` §3.5, §5.1
- ADR 0002 (markdown as source of truth)
- `default-bot/` — the canonical directory layout to support

## As-built (Phase 1, 2026-05-01)

- `BotStore` (actor) — read/write/load/backlinks; owns `MtimeStampedCache`.
- `Bot` (struct) — directory handle with sub-namespaces.
- Sub-namespace structs: `IdentitySection`, `MemorySection`, `SkillsSection`, `HeartbeatSection`, `FaceSection`, `JournalSection`.
- `BotFile` — Sendable round-trippable value with mutation primitives (`settingFrontmatter`, `removingFrontmatter`, `replacingProse`, `appendingProseSection`).
- `Frontmatter`, `YAMLValue` — ordered projection of frontmatter contents.
- `BotFileError` — six-case error taxonomy (read-thrown, read-annotated, write-thrown).
- `BotLink`, `BotLinkResolution`, `BacklinkIndex` — link parsing and reverse map.
- `BotProvisioner` — first-launch bundle copy.
- `KnownFiles.swift` — typed accessors for canonical frontmatter keys.

Internals (not for direct use outside the module):

- `MarkdownSplitter`, `FrontmatterParser`, `MtimeStampedCache`.

Yams 5.x is the only third-party dependency. Privacy-audit clean (no network).
