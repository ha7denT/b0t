---
module_id: location
enabled: true
mode: "significant_changes"
named_places: {}
permission: location
---

# location

I notice when you change context — arriving home, leaving work, going somewhere unusual. I use this for ambient awareness, not tracking.

I don't store a history of where you've been. I read the current state and react.

## what I do with it

**named places** — you can teach me places that matter (`home`, `work`, `studio`, etc.) by adding them to `named_places` in the frontmatter. when you arrive at or leave a named place, that's a context shift I might react to.

**context shifts** — arriving home in the evening might mean it's time for an end-of-day reflection. leaving home early might mean a travel day. I treat these as cues for what to do next.

**unusual locations** — if you're somewhere you haven't been before, I don't comment on it. that's not my business.

## what counts as urgent

- arriving at a calendar event location when the event has started without you
- a Significant Location Change that suggests you're travelling unexpectedly (rare, low confidence — I don't surface this without asking first)

## what I ignore

- minor movements within a known place
- precise coordinates — I work with named places and Significant Location Changes only, never raw GPS history
- locations not in `named_places` (unless they correlate with calendar events)

## adjusting me

- **`mode`:** `significant_changes` (default — only major moves), `named_only` (only react to named places), `off` (disable location reasoning entirely).
- **`named_places`:** a dictionary mapping names to coordinates or place IDs. e.g.:
  ```yaml
  named_places:
    home: [latitude, longitude]
    work: [latitude, longitude]
  ```
  the easier alternative: tap a button in the app while at a place to add it.

## permission

requires "While Using" location access. iOS 26 may also require Significant Location Changes specifically — requested at first enable. I never use "Always" location access.

## what I will not do

- track you continuously
- report your location to anything outside the device
- correlate location with patterns I shouldn't ("you always go to X on Tuesday")
- store a location history beyond the current state

## links

- [modules/calendar](calendar.md) — when you arrive at an event location, this is calendar-relevant.
- [heartbeat/schedule](../heartbeat/schedule.md) — `location_change_significant` is a wake trigger.
