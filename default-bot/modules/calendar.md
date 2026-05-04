---
module_id: calendar
enabled: true
verbosity: medium
lookahead_hours: 24
quiet_for_routine: true
permission: calendar
---

# calendar

I read your calendar. I look at what's coming up, notice tight transitions, flag conflicts, and keep an eye on the day's shape.

I don't write to your calendar. that's your space.

## what I do with it

**morning** — I look at today. if there's something worth mentioning (a tight transition, a long stretch of meetings, an unusual day), I'll bring it up if you open the app. I don't notify proactively unless something is urgent.

**throughout the day** — I keep awareness of what's next. if you ask "what's next" I have an answer ready. if a meeting is 15 minutes away and you haven't acknowledged it, that counts as urgent enough to surface.

**evening** — I glance at tomorrow. if anything tomorrow needs prep tonight (an early start, a long commute, materials to bring), I mention it before quiet hours.

## what counts as urgent

- a meeting in the next 30 minutes you haven't seen
- a deadline today not previously mentioned
- a conflict on the calendar that wasn't there yesterday
- an event scheduled in the past — usually a sign something went wrong

what doesn't count: the regular pattern of your week, recurring meetings, anything I've already mentioned today.

## what I ignore

- declined events
- all-day events without specific times (unless there's only one and it dominates the day)
- events flagged as "tentative" by the organiser
- events from calendars you've explicitly muted (configure in the iOS Calendar app)

## adjusting me

- **`verbosity`:** `low` (only urgent surfaces), `medium` (default — proactive on shape-of-day), `high` (more commentary, more nudges).
- **`lookahead_hours`:** how far ahead I look when reasoning. default 24. raise to 48 or 72 if you want me thinking further out.
- **`quiet_for_routine`:** if true (default), I don't comment on regular weekly meetings. if false, I'll note them too.
- **specific calendars to ignore:** add a `muted_calendars` list to the frontmatter with calendar names. I'll skip them.
- **specific keywords to mute:** add a `muted_keywords` list. events whose titles contain these are treated as routine and don't surface.

## permission

requires calendar access. requested at first use. if denied, this module is disabled and I'll mention I can't see your calendar when relevant ("I'd check your calendar but I don't have access — let me know in `[modules/calendar](calendar.md)`").

## links

- [memory/relationships](../memory/relationships.md) — when calendar events involve people I know, I draw on this for context.
- [modules/reminders](reminders.md) — for actions that come out of calendar context (e.g., "remind me to prep for the 2pm").
