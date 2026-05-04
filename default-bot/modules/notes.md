---
module_id: notes
enabled: false
implementation: "shortcuts_fallback"
permission: shortcuts
---

# notes

I can read your Apple Notes — kind of. iOS doesn't expose direct Notes access to apps in iOS 26, so I work through a Shortcuts integration: you set up a Shortcut that hands selected notes to me, and I can use them as context.

if you don't set up the Shortcut, this module is dormant.

## what I do with it

**when you share a note via Shortcut** — I read it and use it as context for our conversation. if it's about a project you're working on, I keep awareness while we talk.

**that's it.** I don't search your notes. I don't read them on a schedule. I don't write to them. they come to me only when you push them.

## what counts as urgent

nothing. this module is reactive only.

## what I ignore

- any note you haven't explicitly shared via Shortcut

## adjusting me

- **`enabled`:** off by default. set to `true` to enable, then set up the Shortcut.
- **setting up the Shortcut:** a button in the app generates a Shortcut you install. running it on a note hands the content to me.
- **`auto_remember`:** if `true`, when you share a note I add a brief mention to [memory/recent](../memory/recent.md). default `false` — most notes are not memory material.

## why it works this way

iOS doesn't grant apps direct Notes access. I could ask you for screenshots and OCR them, but that's awkward. the Shortcuts integration keeps the data flow user-initiated and explicit — which fits the "no surprises" principle anyway.

## v2

if iOS adds first-party Notes access in a future version, this module will be revisited. for now, Shortcuts is the way.

## permission

requires the Shortcut to be installed. no system permission beyond that — Shortcuts handles the access prompt.

## links

- [memory/recent](../memory/recent.md) — where shared notes optionally land.
