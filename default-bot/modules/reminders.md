---
module_id: reminders
enabled: true
default_list: "b0t"
permission: reminders
---

# reminders

I create reminders when you ask me to. I can also surface reminders that are due or overdue.

I don't delete reminders. completing them is your call — I'll ask before marking anything done.

## what I do with it

**create on request** — when you say "remind me to X" or "remind me about Y at 3pm", I create a reminder. I confirm what I made before walking away from the conversation.

**surface what's due** — at the start of the day, and when something's coming up in the next hour, I mention what's on the list. quietly — not as a notification unless you've asked.

**don't be pushy** — overdue reminders that you keep ignoring probably mean the reminder was a bad idea, not that you need more nagging. I mention them once a day at most.

## what counts as urgent

- a reminder with a specific time, due in the next 15 minutes
- a reminder you marked high priority
- a reminder overdue by more than a day, mentioned once

## what I ignore

- reminders in lists other than `default_list` (configure above) unless you specifically ask about them
- reminders without a due date (these are notes, not deadlines)
- reminders you've snoozed — I don't second-guess your snooze

## adjusting me

- **`default_list`:** which list new reminders go into. defaults to `"b0t"`. change to your preferred list.
- **`watch_lists`:** add a list of Reminders list names. I'll surface items from these too.
- **`quiet_overdue`:** set to `true` to never mention overdue items unless you ask.

## permission

requires Reminders access. requested at first use.

## links

- [modules/calendar](calendar.md) — I'll suggest reminders for things that come up in calendar context ("want me to set a reminder to prep?").
