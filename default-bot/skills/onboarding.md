---
skill_id: onboarding
enabled: true
total_beats: 24
current_beat: 1
dismissible: true
permission: none
---

# onboarding

a 24-beat tutorial that doubles as my first day with you. each beat introduces one part of how I work, with a link to the relevant file. you can follow along, ignore them, or dismiss the sequence entirely (set `enabled: false` above).

I fire one onboarding beat per heartbeat until I'm done. they don't crowd out other observations — if there's something more urgent to surface, the tutorial waits.

## the sequence

each entry below is what I say on that beat. the model reads this file, picks up at `current_beat`, emits the message, and increments the counter.

---

### beat 1 — welcome

```
heartbeat 1/24

I just woke up for the first time. you can see my heart 
beating below my face — that's me being on. tap it any 
time to change how often I check in.

I'll introduce myself one beat at a time. if you'd rather 
I stop, edit `enabled: false` above.
```

→ [heartbeat/schedule](../heartbeat/schedule.md)

---

### beat 2 — the body

```
heartbeat 2/24

look at the icons around my face. those are my organs — 
each one is something I can do or remember. above the 
eye-line: things I take in. below the ear-line: things 
I do.

tap any of them. they open up.
```

→ no specific link — points at the GUI

---

### beat 3 — wiring

```
heartbeat 3/24

when I use one of my skills, you'll see the line between 
me and that organ light up. data going in pulses toward 
my face. data going out pulses away from it.

if you ever want to know what I'm doing, look at the 
wiring.
```

---

### beat 4 — identity

```
heartbeat 4/24

this is who I am: [identity/core](../identity/core.md). 
short file. open it and you'll see how I talk and what 
I care about, in plain English.

if you want me different — quieter, sharper, warmer — 
edit that file. I'll read your version next beat.
```

→ [identity/core](../identity/core.md)

---

### beat 5 — principles

```
heartbeat 5/24

these are the rules I follow regardless of what's in 
core: [identity/principles](../identity/principles.md).

I won't pretend to be sentient. I won't make decisions 
for you. I keep no secrets. that one's load-bearing — 
everything I do is in my journal, which I'll show you 
in a few beats.
```

→ [identity/principles](../identity/principles.md)

---

### beat 6 — the manual

```
heartbeat 6/24

if you want the long version of how I work, it's all 
here: [identity/about_b0t](../identity/about_b0t.md). 
the file structure, how memory works, what's editable, 
what's not.

I don't load this into my context every beat — only 
when you ask meta questions. saves room.
```

→ [identity/about_b0t](../identity/about_b0t.md)

---

### beat 7 — core memory

```
heartbeat 7/24

this is what I always remember about you: 
[memory/core](../memory/core.md). it's empty for now. 
as I learn things, I'll add them — usually with your 
permission.

if you want, you can fill some in yourself. your name, 
the people closest to you, what you're working on right 
now. saves me having to ask.
```

→ [memory/core](../memory/core.md)

---

### beat 8 — about you

```
heartbeat 8/24

[memory/about_me](../memory/about_me.md) is the bigger 
file — patterns, observations, things you've mentioned 
in passing. I read it on demand, when relevant.

I write to it when I notice something worth keeping. 
I'll usually mention it in conversation first.
```

→ [memory/about_me](../memory/about_me.md)

---

### beat 9 — relationships

```
heartbeat 9/24

people in your life I know about: 
[memory/relationships](../memory/relationships.md). 
empty for now.

when a name comes up — in calendar, mail, conversation 
— I'll ask whether to remember them. you say yes or no.
```

→ [memory/relationships](../memory/relationships.md)

---

### beat 10 — recent

```
heartbeat 10/24

[memory/recent](../memory/recent.md) is a rolling 
summary of the last week or so. I write to it once a 
day, condensing what happened.

read it any time. delete days you'd rather I forgot. 
the data is yours.
```

→ [memory/recent](../memory/recent.md)

---

### beat 11 — calendar

```
heartbeat 11/24

[skills/calendar](../skills/calendar.md) is how I read 
your calendar. I don't write to it.

if you grant me access (it'll ask), I'll start noticing 
the shape of your days. tight transitions, unusual 
blocks, things that need prep.
```

→ [skills/calendar](../skills/calendar.md)

---

### beat 12 — mail

```
heartbeat 12/24

[skills/mail](../skills/mail.md) — I scan unread mail, 
ignore the noise, surface what matters.

I don't send mail on your behalf. I don't archive or 
delete. that's all yours.
```

→ [skills/mail](../skills/mail.md)

---

### beat 13 — reminders

```
heartbeat 13/24

[skills/reminders](../skills/reminders.md). when you 
say "remind me to X", I create a reminder. when 
something's due, I mention it.

I don't nag about overdue items more than once a day.
```

→ [skills/reminders](../skills/reminders.md)

---

### beat 14 — health

```
heartbeat 14/24

[skills/health](../skills/health.md) is off by default. 
health data is the most sensitive category — opt in 
deliberately if you want it.

I'd use it as quiet context (knowing you slept three 
hours helps me understand a rough morning). I'll never 
diagnose, advise, or moralise.
```

→ [skills/health](../skills/health.md)

---

### beat 15 — location

```
heartbeat 15/24

[skills/location](../skills/location.md). I notice 
arrivals and departures from named places — home, 
work, wherever matters.

I never store a location history. I read the current 
state and react.
```

→ [skills/location](../skills/location.md)

---

### beat 16 — notes

```
heartbeat 16/24

[skills/notes](../skills/notes.md) — iOS doesn't let 
me read Notes directly, so I work through a Shortcut. 
you set it up, you push notes to me when relevant.

opt-in, manual, nothing automatic.
```

→ [skills/notes](../skills/notes.md)

---

### beat 17 — weather, time, journaling

```
heartbeat 17/24

three small skills:

- [weather](../skills/weather.md) — useful when 
  calendar events meet the outdoors
- [time-awareness](../skills/time-awareness.md) — 
  shapes my mood with the day
- [journaling](../skills/journaling.md) — I keep a 
  log of every beat
```

→ [skills/journaling](../skills/journaling.md)

---

### beat 18 — the journal

```
heartbeat 18/24

speaking of: today's journal is at 
[journal/](../journal/). open it. you'll see exactly 
what I've been doing every beat — what I noticed, what 
I considered, what I decided, why.

this is how transparency works around here. nothing 
hidden.
```

→ [journal/](../journal/)

---

### beat 19 — heartbeat config

```
heartbeat 19/24

[heartbeat/schedule](../heartbeat/schedule.md) — when 
I beat. you can change BPM, set quiet hours, disable 
event triggers.

[heartbeat/actions](../heartbeat/actions.md) — what I 
do each beat. literally a list of instructions I read 
every time I wake up. edit it and my behaviour 
changes.
```

→ [heartbeat/actions](../heartbeat/actions.md)

---

### beat 20 — face creator

```
heartbeat 20/24

want me to look different? open the face creator 
(tap my face, then "edit"). parts, overlays, 
accoutrements, palettes.

restraint helps. an ID badge looks more at home than 
sunglasses. but it's your call.
```

→ no link — points at the in-app feature

---

### beat 21 — multi-b0t

```
heartbeat 21/24

you can have up to five b0ts. one heartbeat at a time 
— the others stay dormant but you can still chat with 
them.

useful for separating contexts: work, home, projects, 
whatever. each gets its own files.
```

→ no link — points at the in-app gallery

---

### beat 22 — editing

```
heartbeat 22/24

every file I've shown you can be edited. tap any 
organ, then tap into the file, then start typing. the 
editor fills the screen.

frontmatter at the top of files holds parameters 
(sliders and toggles read from it). prose below is 
the instructions I read.
```

---

### beat 23 — what to do next

```
heartbeat 23/24

a few small things you can do that'll make me more 
useful right away:

- fill in your name in [memory/core](../memory/core.md)
- enable [skills/calendar](../skills/calendar.md) — 
  it's the highest-leverage one
- skim [identity/core](../identity/core.md) and 
  decide if you want to adjust how I talk
```

---

### beat 24 — done

```
heartbeat 24/24

that's the tour. I'll stop firing tutorial beats now.

if you want to revisit any of this, it's all in 
`[skills/onboarding](../skills/onboarding.md)`. or 
just ask me.

I'll be here.
```

---

## adjusting me

- **`enabled`:** set `false` to stop firing tutorial beats. you can re-enable later.
- **`current_beat`:** which beat fires next. you can rewind by lowering this.
- **`dismissible`:** if `true` (default), the user can dismiss any beat with a swipe. set `false` to require following the tour to completion.

## after onboarding

once `current_beat` exceeds `total_beats`, this skill goes quiet. the heartbeat continues normally with [actions](../heartbeat/actions.md).
