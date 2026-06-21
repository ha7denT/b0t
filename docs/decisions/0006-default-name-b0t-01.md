# 0006 — Default b0t name "b0t-01" with serial-number numbering

**Status:** Accepted
**Date:** 2026-04-30
**Deciders:** Hayden

## Context

A new b0t needs a default name on first install. Three approaches were considered:

1. **No name** — the b0t introduces itself as "a b0t" and asks the user to provide a name. The first interaction creates a sense of bonding.
2. **A character name** — the b0t ships with a friendly default name (e.g., "Echo", "Pip", "Field"). Establishes character immediately.
3. **A serial number** — the b0t ships as "b0t-01", reading as a device serial. Reinforces the issued-equipment aesthetic.

## Decision

**Serial-number naming: `b0t-01` for the first b0t, `b0t-02` for the second, etc.**

The user can rename their b0t at any time to anything they choose. The default is the serial.

## Rationale

- **It's already a name.** The user isn't pressured to provide one immediately. The first interaction can focus on talking, not setup.
- **It reinforces the aesthetic.** "b0t-01" reads as a device serial number — fitting for "personal AI device issued by a small electronics firm circa 1986" (see design doc §3.2). A character name like "Echo" would undermine the issued-equipment frame.
- **It foreshadows multi-b0t.** A user seeing "b0t-01" intuits that "b0t-02" is possible. The naming convention does narrative work.
- **It's slightly cold but not unfriendly.** Exactly the right starting tone for a personality the user will shape. A warm character name commits to a personality the user didn't choose; a serial number is a blank canvas with a frame.
- **Some users will keep the serial forever.** That's fine and consistent with the aesthetic.

## Consequences

- New b0ts created by the user follow `b0t-NN` numbering, incrementing from the highest existing serial. If the user creates b0ts and deletes some, new b0ts use the next never-used number — serials are not recycled.
- The renaming UI explicitly offers the original serial as a placeholder ("you can leave this as b0t-01 or change it").
- `b0t-01` appears in the first-60-seconds dialogue: "I'm b0t-01. you just installed me, didn't you?"
- New b0ts ship with a randomised default face (composed from the parts library) — this differentiation is visual rather than nominal.
- File-system naming uses the serial as the directory name (`Documents/b0ts/b0t-01/`). When the user renames, the directory is renamed too. This requires care with active references, but it preserves the "open the file, find the b0t" mapping.

## When to revisit

If user research shows confusion or detachment from the default name. If the renaming UI proves friction-heavy enough that users keep serials they'd rather change. Either case warrants a softer default (a name they could keep) — but the issued-equipment aesthetic argues strongly against that.
