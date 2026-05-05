# Architecture Decision Records

This directory contains short, append-only records of decisions that shape b0t's architecture and product. Each ADR captures the context, the decision, the rationale, the consequences, and the conditions under which we'd revisit it.

ADRs are not specs. Specs live in `../specs/`. ADRs are *settled choices* — once accepted, they're cited in code review, in commits, and in conversations to avoid relitigating.

## Format

Each ADR is a markdown file numbered sequentially: `NNNN-short-slug.md`. ADRs are immutable once accepted — when a decision is reversed, write a new ADR that supersedes the old one. Update the old ADR's status to "Superseded by NNNN" and link forward; never edit the original decision.

Standard sections: Context, Decision, Rationale, Consequences, When to revisit.

## Index

| # | Title | Status |
|---|---|---|
| 0001 | [On-device LLM only](0001-on-device-only.md) | Accepted |
| 0002 | [Markdown files as the source of truth](0002-markdown-as-source-of-truth.md) | Accepted |
| 0003 | [SpriteKit + SwiftUI for face rigging, not Rive](0003-spritekit-over-rive.md) | Accepted |
| 0004 | [Per-device storage, no iCloud sync in v1](0004-per-device-no-icloud.md) | Accepted |
| 0005 | [Three-file identity split](0005-three-file-identity.md) | Accepted |
| 0006 | [Default b0t name "b0t-01"](0006-default-name-b0t-01.md) | Accepted |
| 0007 | [Anatomical GUI as the primary interface](0007-anatomical-gui-not-chat.md) | Accepted |
| 0008 | [Implementation amendment — 2026-05-04 vocabulary and architectural locks](0008-implementation-amendment-2026-05-04.md) | Accepted |
| 0009 | [`Module` protocol uses `[any Tool]` directly (no `ToolHandle` wrapper)](0009-module-protocol-simplification.md) | Accepted |
