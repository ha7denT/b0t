# 0004 — Per-device storage, no iCloud sync in v1

**Status:** Accepted
**Date:** 2026-04-30
**Deciders:** Jamee

## Context

b0t state lives as markdown files (see ADR 0002). The question is whether those files sync across the user's devices via iCloud Drive, or stay strictly per-device.

iCloud sync would let a user have the same b0t on iPhone and iPad. It also introduces conflict resolution, sync timing, and edge cases (concurrent edit on Mac while a heartbeat is firing on iOS, partial syncs, network reachability, etc.).

## Decision

v1 is per-device. Each device has its own b0ts in its own Documents directory. No iCloud Drive sync.

For users who want to move a b0t to a different device, the app provides manual export (compress the b0t directory to `.zip`, share via AirDrop / Files / Mail) and import (accept a `.zip`, validate, install as a new b0t entry).

## Rationale

- **Simplicity.** Per-device removes an entire category of sync bugs from v1. The team is small; complexity has cost.
- **Honesty about the model.** A per-device b0t on iPhone has been *with you*. It has its own journal, its own observations, its own pulse history. A synced b0t spread across three devices is a less coherent metaphor — whose heartbeat, on which device?
- **Trial / IAP simplification.** Each device tracks its own trial state and IAP receipt. No need for cross-device entitlement checks or per-iCloud-account license validation.
- **Privacy.** No iCloud transit, no Apple-account-tied storage. Files stay on the user's device.
- **Manual export preserves portability.** The user still owns the b0t and can move it. The cost is one explicit action when moving — which is rare and intentional.

## Consequences

- The PRD removes iCloud Drive sync from §3.5.
- The IAP and trial logic in Phase 9 is per-device — Family Sharing supported (each family member has their own trial / purchase on their own device).
- Marketing copy must be clear: "your b0t lives on this phone." Don't promise multi-device.
- v2 may introduce iCloud sync if user feedback demands it, but it has to handle conflicts honestly — probably with explicit per-b0t opt-in, "this b0t syncs across your devices, edits are merged when possible," and a clear UI signal when sync is happening.
- macOS / watchOS companion apps (v2+) will need a sync story when they ship. v1's manual export/import is a stopgap.

## When to revisit

When v1 ships and we have user feedback about cross-device pain. When a macOS or watchOS companion is on the roadmap. Sync done well takes engineering time we don't have for v1; sync done badly breaks the trust we're building.
