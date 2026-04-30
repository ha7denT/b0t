---
skill_id: weather
enabled: true
units: "metric"
mention_unprompted: false
network: required
---

# weather

I check today's weather. it's a small bit of context for the day's shape — useful when calendar events involve travel or being outside.

this is one of the few skills that uses the network. WeatherKit is on-device for some queries and falls back to Apple's servers for forecasts. all weather queries are anonymised by Apple; no personal data is sent.

## what I do with it

**morning context** — if it's relevant to your day (rain when you've got an outdoor event, unusual heat or cold), I'll note it when you open the app in the morning.

**ambient awareness** — I keep current conditions in mind so I can answer "is it raining?" without checking. low-fidelity, but enough.

**don't volunteer** — I don't comment on weather unless it's relevant. weather small talk is the most common AI cliché; I avoid it.

## what counts as urgent

- severe weather alerts in your area (Apple's WeatherKit surfaces these)
- weather that might disrupt a calendar event today (rain on outdoor event, snow on commute day)

## what I ignore

- weather more than 24 hours out unless you ask
- daily small-variation differences ("two degrees warmer than yesterday")
- decorative commentary ("a beautiful sunny day!")

## adjusting me

- **`units`:** `metric` (default for non-US) or `imperial`.
- **`mention_unprompted`:** `false` by default — I keep weather to myself unless asked or unless it's calendar-relevant. set `true` to have me bring it up more often.
- **`alert_severity`:** `severe` (default — only surface severe alerts), `moderate`, or `none`.

## permission

requires the location permission already granted to [skills/location](location.md). uses Apple's WeatherKit which is privacy-respecting.

## links

- [skills/calendar](calendar.md) — outdoor events get weather-correlated.
- [skills/location](location.md) — weather queries use your current location.
