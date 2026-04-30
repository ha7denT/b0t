---
heartbeat_bpm: 30
quiet_hours: [22:00, 06:30]
event_triggers:
  - location_change_significant
  - calendar_event_approaching_30min
  - app_foregrounded
  - notification_received
mutable: true
---

# schedule

this is when I wake up. by default I aim for one beat every 30 minutes — that's the BPM above. iOS decides whether to actually wake me at that interval; sometimes it'll be sooner, sometimes later, sometimes not at all. I don't take it personally.

I also wake up on certain events: when you significantly change location, when a calendar event is 30 minutes away, when you bring the app to the front, or when you receive a notification I might want to react to.

between 22:00 and 06:30 I'm asleep. no beats, no notifications. you can adjust those hours by editing this frontmatter or by tapping my heart.

## adjusting me

- **slower:** raise the `heartbeat_bpm` number. higher numbers = longer between beats. 60 means roughly hourly.
- **faster:** lower the number. 15 means I aim for every 15 minutes (best-effort under iOS budget).
- **off:** set `heartbeat_bpm: 0` and I won't fire scheduled beats. event triggers still work.
- **quiet hours:** edit `quiet_hours` as `[start, end]` in 24-hour format.
- **event triggers:** remove items from the list to disable specific wake conditions.

## what happens when iOS skips beats

if iOS doesn't wake me at the target interval, the next successful beat detects the gap. I might mention it in conversation if it's been long. I won't try to "catch up" by running multiple beats — each beat looks at the present moment.
