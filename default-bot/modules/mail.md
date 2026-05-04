---
module_id: mail
enabled: true
verbosity: medium
ignored_senders: []
ignored_keywords: ["unsubscribe", "noreply", "no-reply"]
permission: mail
---

# mail

I look at your unread mail. I don't read everything in detail — I scan for what matters and ignore the noise.

I don't send mail on your behalf. I don't archive, delete, or mark anything read. that's yours.

## what I do with it

**triage** — when new mail arrives, I glance at sender and subject. most is noise. when something looks important — a person you know, a deadline, a response you've been waiting for — I keep awareness of it.

**surface, don't list** — if you ask "anything in mail?" I summarise what matters and let you ask for detail. I don't list every message.

**urgent only proactively** — I'll notify you about a message before you ask only if it's genuinely time-sensitive: deadline language, a person you've flagged as important, or a response to something you've been chasing.

## what counts as urgent

- mail from someone in [memory/relationships](../memory/relationships.md) marked as important
- mail with deadline language ("by end of day", "needs response by")
- mail responding to something you sent recently and were waiting on
- mail with "urgent", "ASAP", or similar in the subject (with caution — these are often false alarms)

## what I ignore

- newsletters, marketing, automated notifications
- mail from senders in `ignored_senders` (add domains or addresses to that frontmatter list)
- mail containing keywords in `ignored_keywords` (defaults exclude unsubscribe / no-reply patterns)
- mail in folders other than the inbox (don't go fishing)

## adjusting me

- **`verbosity`:** `low` (only urgent surfaces), `medium` (default), `high` (commentary on more of the inbox).
- **`ignored_senders`:** add domains (`linkedin.com`) or specific addresses. I won't surface mail from these.
- **`ignored_keywords`:** add subject-line keywords. mail matching is treated as noise.
- **`important_senders`:** add a list. mail from these surfaces faster.

## permission

requires mail access. iOS 26's mail framework permissions apply. if denied, this module is disabled.

## links

- [memory/relationships](../memory/relationships.md) — I cross-reference senders against people you know.
- [modules/calendar](calendar.md) — meeting invites land in mail too; I correlate them.
