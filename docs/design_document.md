# b0t — Design Document

**Document type:** Design Document
**Audience:** Designer (you), Claude Code (coder), future collaborators
**Status:** v1.0 — design lock for v1 development
**Last updated:** 2026-04-29

---

## 0. One-line description

b0t is a personal AI companion you grow yourself, on your phone, in plain text.

---

## 1. Philosophy

### 1.1 The thesis

Every AI companion app on the market is a service. You rent a personality. You rent a memory. You rent a relationship with software you don't own and can't see inside. When the company changes the model, your companion changes. When the company shuts down, your companion dies.

b0t inverts this. Your b0t lives entirely on your device. Its personality is a markdown file. Its memories are markdown files. Its skills are markdown files. You can open them, read them, edit them, share them, version them, back them up. The app is a body for files you own.

The on-device LLM (Apple's Foundation Models framework) is the engine that animates these files. It's small, free, private, and offline. It is not a vast intelligence. b0t doesn't pretend otherwise.

### 1.2 The five principles

1. **Your b0t is yours.** No subscription, no cloud, no account. Files live in the user's Documents directory or iCloud Drive, in plain markdown. The app can be deleted; the b0t survives. The b0t can be airdropped to a friend.
2. **Honesty about fidelity.** The visual and interaction design tells the truth about what the system is — a small local model executing a heartbeat loop animating a markdown character. No photorealism, no claims of sentience, no smoke and mirrors. Cassette-futurism aesthetic because cassette futurism is honest about technology being a manufactured object with constraints.
3. **The system is legible.** The user can always see what their b0t is doing. Every capability is visible as an organ on the body. Every active operation lights up wiring. Every memory and skill is a file the user can open. Black-box AI is the opposite of what b0t is.
4. **The user assembles their b0t.** b0t ships with a default personality and a curated skill library. The user composes from these and edits to make it theirs. b0t is a substrate, not a product. The user is the product.
5. **Restraint.** Most of the time, b0t is quiet. The face breathes, the heart beats. Notifications are rare and meaningful. Conversation is calm. Animation is sparse. Sound is sparing. Activity has weight because it isn't constant.

### 1.3 What b0t is not

- A productivity tool with a face on it.
- A friend who solves your loneliness.
- A character chatbot.
- A general-purpose assistant.
- A novelty.

b0t is closer in category to Obsidian, Things, or a really good notebook than to ChatGPT or Replika. It's a tool the user develops a long relationship with because the more they put in, the more it becomes theirs.

---

## 2. The four pillars

### 2.1 Markdown brain

Every b0t is a directory of markdown files on disk. The structure:

```
~/Documents/b0ts/
├── _active                          # pointer file naming the active b0t
├── b0t-01/                          # default name; user can rename
│   ├── identity/
│   │   ├── core.md                  # voice anchor + behavioural defaults (always loaded)
│   │   ├── principles.md            # safety contract (always loaded)
│   │   ├── about_b0t.md             # the manual, in b0t's voice (loaded on demand)
│   │   ├── appearance.md            # face params (frontmatter), aesthetic notes
│   │   └── audio.md                 # TTS filter, pitch, rate
│   ├── memory/
│   │   ├── core.md                  # always-included facts about the user
│   │   ├── about_me.md              # what b0t has learned about the user
│   │   ├── relationships.md         # people in the user's life
│   │   ├── recent.md                # last N days, auto-summarised
│   │   └── archive/                 # older summarised digests
│   ├── skills/
│   │   ├── calendar.md
│   │   ├── mail.md
│   │   ├── reminders.md
│   │   └── ...
│   ├── heartbeat/
│   │   ├── schedule.md              # frequency, quiet hours, conditions
│   │   └── actions.md               # what to do each beat
│   ├── journal/
│   │   └── 2026-04-29.md            # b0t's heartbeat log for this day
│   └── face/                        # face composition files (see §2.4)
├── b0t-02/
│   └── ...
└── _shared/
    └── skills/                       # skills shared across all b0ts
```

**File ownership:** every file is either user-editable, b0t-editable, or both. b0t writes to `memory/recent.md`, `memory/relationships.md` (with permission), `journal/`, and the auto-summarisation passes. The user owns everything else, though the user can edit any file at any time.

**Frontmatter for parameters.** Files with structured controls (heartbeat schedule, skill verbosity, voice settings) use YAML frontmatter for the parameters and prose below for the instructions:

```markdown
---
heartbeat_bpm: 30
quiet_hours: [22:00, 06:30]
---

# Heartbeat

This is how often I check in on things.
At 30 BPM I tick roughly every two minutes when active...
```

Sliders and toggles in the GUI read from and write to frontmatter. Prose stays the user's space.

**Inter-file linking.** Files reference each other with markdown links: `[onboarding](skills/onboarding.md)`. The in-app viewer intercepts these and routes to the relevant organ. Backlinks are computed and shown — b0t's mind is a small personal wiki.

### 2.2 Configurable heartbeat

The heartbeat is the central metaphor. It is also the actual scheduling mechanism. Heartbeats are how b0t does anything autonomously.

**Each beat:**
1. b0t wakes (background task, event trigger, or app-foreground tick).
2. Loads the active b0t's identity core, memory core, and the current beat's instructions from `heartbeat/actions.md`.
3. Loads any skill files relevant to the current context.
4. Runs a fresh `LanguageModelSession` with this assembled context.
5. Returns a typed `@Generable` decision: observe, act, notify, sleep.
6. If acting, executes via tool calls (read calendar, write reminder, post notification).
7. Writes a journal entry recording what happened.
8. Updates `memory/recent.md` with any new observations.
9. Schedules the next beat.

**Configurability:**
- BPM — sets the target frequency. Slow (every 60+ min), Medium (every ~30 min), Fast (every ~15 min, best-effort under iOS background limits).
- Quiet hours — beats don't fire, no notifications.
- Per-beat actions — the user can edit `heartbeat/actions.md` to script what each beat does.
- Trigger conditions — beats can also fire on events (location change, calendar event approaching, notification arrival, app launch).

**Realism about iOS background execution:** the heartbeat is best-effort. iOS schedules background tasks at its discretion. Fast BPM is aspirational; medium and slow are reliable. Event triggers are most reliable of all. b0t communicates this honestly — when the user opens the app after an absence, b0t can say "I was asleep for a while — iOS didn't wake me. Here's what's happened since."

**The heartbeat is also the onboarding mechanism.** The first 24 heartbeats double as the tutorial, each beat referencing one organ via inter-file link, gently introducing the system. See §6 for the first-60-seconds spec.

### 2.3 Anatomical GUI

The home screen of b0t is the b0t themselves — a face surrounded by a body of organs, with the heart at the centre, all wired together with visible energy lines. This is not a chrome around a chat interface. The character is the interface.

**Layout (portrait):**
- **Top half:** the b0t's face, breathing, blinking, occasionally glancing.
- **Around the face:** organ icons arranged anatomically.
  - Above the eye-line: things that come in — perception (calendar awareness, mail awareness, location, hardware sensors), core memory, identity files.
  - Below the ear-line: things that go out — actions, tools, skills (reminders, notifications, mail compose, calendar writes).
  - Left and right balance for visual symmetry; assignment is by category, not arbitrary.
- **Centre, directly below face:** the heart. Beats at the configured BPM. Tappable to access heartbeat config.
- **Bottom half:** the chat surface. Conversation appears here.

**Energy wiring.** When an organ is being accessed, the line between face and organ illuminates. Direction matters: data flowing into b0t (reading) pulses from organ to face; data flowing out (writing) pulses from face to organ. This is the system's nervous system, made visible.

**Privacy shield.** A semi-transparent overlay can hide organ details — useful when handing the phone to someone, or when the user wants a calmer view. The b0t still functions; the shield is cosmetic.

**Tap interactions:**
- Tap face → focus mode (face zooms, chat compresses).
- Tap organ → the organ's `.md` content appears in the lower half, replacing chat.
- Begin editing in lower half → editor expands to full screen.
- Tap heart → heartbeat configuration sheet (BPM slider, quiet hours, schedule editor).
- Long-press anywhere → reveal the underlying file path (power-user mode).

**Mode switching is fluid.** Chat ↔ inspect ↔ edit are register changes within the same screen, not separate views. The b0t's face stays visible during inspect (smaller); only edit fills the screen, because editing demands focus.

**Notifications carry the active b0t's face.** When b0t pings the user, the notification icon is the b0t's face in the appropriate mood (worried for urgent, curious for question, etc.). 6–8 mood variants are pre-rendered per b0t at face-creation time.

### 2.4 Multi-b0t and Face Creator

**The roster.** The user can create multiple b0ts. Each lives in its own directory. Only one is active (has a beating heart) at any time. Inactive b0ts retain memory, identity, and files; they're just dormant.

**The gallery.** A wallet-style picker showing all the user's b0ts. The active b0t is visibly alive (breathing, heart beating, eyes tracking). Dormant b0ts are still, eyes closed. Switching is a deliberate gesture (hold-and-drag or pull-to-activate) — friction here is good.

**Conversation with dormant b0ts is allowed.** The active b0t is the only one with proactive behaviour and background work. Any b0t can be opened and chatted with directly. This means dormant b0ts are not dead; they're just off duty.

**Soft cap of 5 b0ts in v1.** Justified as "your inner circle." Lift later if there's demand.

### 2.5 Face Creator

The Face Creator is a feature-grade sub-product. Designing the face is part of how the user bonds with their b0t.

**Architecture: parts + overlays + accoutrements.**
- **Parts** are the b0t's anatomy — face shape, eye shape, mouth shape, brow style. Each part is a rigged sprite that animates (blinks, speaks, expresses). Parts are designed as a system: every combination is coherent.
- **Overlays** are patterns applied to parts — freckles, scanlines, pixel grain, dithering patterns. Overlays follow the part's rig.
- **Accoutrements** are added items — antennae, scanner visors, indicator lights, ID badges, hazard stripes. **Issued-equipment aesthetic, not novelty cosplay.** No cat ears, no sunglasses, no whimsy props. Every accoutrement reinforces the "personal device issued by a small electronics firm in 1986" feel.

**Palette system.** The user picks a curated palette per b0t (3-5 colours). Parts and overlays use named slots — `primary`, `accent`, `shadow`, `highlight` — that map to the palette. Changing the palette recolours the entire b0t coherently. **No arbitrary RGB picker** — palettes are curated, all designed to look good in the cassette-futurism aesthetic.

**Animation states baked into parts.** Idle (breathing, blinking, glancing), speaking, thinking, surprised, sleepy, attentive, worried, delighted. ~8 emotional states. The Creator preview shows the face cycling through states, not a static portrait.

**Randomise / shuffle.** A button that produces a pleasing combination every time. Most users will use this and tweak. A small set of starter templates are also provided.

**The Creator surface ages with use.** As the user spends time with their b0t, subtle wear can accumulate (optional, disabled by default). Patina, not damage. Death-Stranding-style equipment that earns its scuffs.

---

## 3. Aesthetic direction

### 3.1 The reference set

- **Simon Stålenhag** — domestic technology in lived environments, painterly fidelity that admits to being constructed.
- **Ron Cobb's *Alien* semiotics** — restrained, functional, in-fiction industrial design.
- **Lumon UI from *Severance*** — UI that has been in service for thirty years, simple and weathered.
- **Death Stranding's operational interfaces** — cold technical UI rendered with Bridges' in-fiction design language.
- **Teenage Engineering** — functional minimalism with emotional warmth, the OP-1 sensibility.
- **Replaced (Thunderful Games)** — pixel art with cinematic chiaroscuro, sodium-vapour atmosphere.
- **Kingdom Two Crowns** — pixel art with painterly lighting, depth without breaking the grid.
- **CRT glow and scanlines** — the substrate that ties the technological references together.

### 3.2 The synthesis

**A personal AI device issued by a fictional small electronics firm circa 1986. Pixel art rendered with painterly lighting. UI semiotics in the Cobb/Lumon tradition — restrained, functional, slightly aged. Teenage Engineering design discipline. Sound and motion as considered and rare as in *Severance*. The user's b0t is a piece of equipment that ages with use.**

### 3.3 Visual language layers

The app uses register shifts between layers, each matching its content:

- **The b0t themselves** — pixel art with painterly lighting. Limited palette per b0t. Animated rig. This is where personality lives.
- **The body, organs, wiring** — vector display / CRT. Phosphor-glow lines, electrical schematics, energy flow visualisation. Slight bloom and scanline. This is where capability and system state live.
- **The brain (.md files and inspection)** — technical manual / diagrammatic. Monospaced type, annotations, callouts. This is where structure and editability live.
- **Chat** — clean editorial. Generous type, comfortable line-length, slightly aged sans-serif. This is where conversation lives. The least stylised layer because conversation should feel most natural.

These layers share palette, grid, and underlying logic. Transitions between them are register shifts within a unified system.

### 3.4 Type

- **Brain layer (`.md` files):** **IoskeleyMono NL.** Open-source monospace built for technical text — sharply drawn, readable at small sizes, ligature-free (the "NL" suffix). Used for all markdown viewing and editing, frontmatter parameters, and all monospaced UI elements.
- **Chat:** **Söhne.** Humanist sans-serif with the right amount of warmth — present but never sterile. Used for the b0t's conversation and the user's input.
- **System UI labels:** IoskeleyMono NL small caps, sparingly used, for organ labels and status indicators (Cobb/Lumon influence).
- **The b0t's name, when shown:** pixel art rendered, custom per b0t.

### 3.5 Colour

- **App-wide base:** warm dark — not pure black. Think aged plastic, dimmed CRT, dark amber background. Cool blacks are clinical; warm darks are domestic.
- **Phosphor glow:** the wiring and active organs glow in a warm phosphor — amber, green, or cream. Never blue. Blue is sterile and tech-coded; warm phosphor is alive.
- **b0t palettes:** curated. 3-5 colours per palette, designed together. Earthy bases, muted tones, single saturated accent. Stålenhag-disciplined.

### 3.6 Motion

- **Idle:** breathing (face), beating (heart), occasional blink, occasional glance off-screen. Always present, never distracting.
- **Active:** wiring lights up, organ pulses, optional brief motion of face toward the active region.
- **Transitions:** register shifts (chat ↔ inspect, normal ↔ edit) use diegetic motion — the chat surface dims and slides, the inspection layer fades up like a CRT warming.
- **Restraint:** every animation should feel earned. Most of the time, b0t is quiet.

### 3.7 Sound

- **Ambient hum** when b0t is awake — very quiet, optional.
- **Heartbeat tick** at the configured BPM, very faint. Off by default; users opt in if they want.
- **Action sounds** — clicks, soft thunks, tape-warble for transitions. OP-1 / classic Mac sensibility, not chiptune.
- **TTS voice** — `AVSpeechSynthesizer` piped through `AVAudioEngine` with effect filters: Clean, Warm, Tape, FM, Radio, Distant, Vintage, Hi-Fi. The user picks a filter per b0t. The Tape filter is the brand voice — slight wow-and-flutter, low-pass, gentle saturation.
- **Mute is a valid setting.** The default has presence; the user can silence it entirely.

---

## 4. Skills

### 4.1 What a skill is

A skill is a `.md` file describing how b0t should think about and use a particular capability. The actual system access (EventKit for calendar, Mail framework, HealthKit, Core Location) is hardcoded Swift. The `.md` file is the prompt-and-behaviour spec.

This separation matters: users can compose new behaviours from existing primitives, but they can't add raw new system permissions through a markdown file. New capabilities (and their permissions) ship in app updates.

### 4.2 v1 skill library

Curated set, all hand-written by the team, all expressing the cassette-futurism voice:

1. **Calendar** — read events, summarise the day, surface conflicts, comment on tight transitions.
2. **Mail** — triage unread, surface what matters, ignore rules user can edit.
3. **Reminders** — create, complete, schedule.
4. **Health** — read step count, sleep quality, comment on patterns.
5. **Location** — knows when home/work/elsewhere, can react to arrivals.
6. **Notes** — read Apple Notes, surface relevant ones to context.
7. **Weather** — situational awareness.
8. **Time/Calendar awareness** — day of week, time of day, holidays, time elapsed.
9. **Journaling** — b0t maintains its own journal of observations about the user.
10. **Onboarding** — the 24-heartbeat tutorial sequence.

### 4.3 Skill file format

Each skill is a markdown file with frontmatter for parameters and prose for behaviour:

```markdown
---
skill_id: mail
enabled: true
verbosity: medium
ignored_senders: ["linkedin.com", "noreply"]
---

# Mail

When I check the user's mail, I look for things that matter to them right now.
I ignore newsletters, automated notifications, and anything from the senders
listed above. I'm especially interested in messages from people in
[memory/relationships](memory/relationships.md).

When I find something worth surfacing, I bring it up in conversation
naturally — I don't list every email. I summarise the gist and let the
user ask for detail.

If something seems urgent (deadline language, time-sensitive requests),
I notify directly. Otherwise I wait for the user to ask.
```

### 4.4 Skill portability

Skills are plain `.md` files. Users can:
- Edit them directly.
- Disable them via frontmatter.
- Share them by airdropping the file to another user.
- Move skills between b0ts by copying files.

v2 ships an online repo / skill library where users can publish and discover skills.

---

## 5. Identity, personality, memory

### 5.1 The identity files

The b0t's identity is split across three files, each with a different role and loading behaviour:

**`identity/core.md`** — the voice anchor. Always loaded into every model call. Defines who the b0t is, how they speak, and what they care about. Modelled in its writing style — the prose itself is voice training, not just instruction. Target ~250 tokens. The shipped default for b0t-01 is a starting point; the user can edit or replace entirely. The user changes this file, the b0t's voice changes.

**`identity/principles.md`** — the safety contract. Always loaded. Hard behavioural rules that hold regardless of how the user has shaped `core.md`: not pretending to be sentient, not making decisions for the user, no hidden state, respecting the user's edits. Marked `mutable: false` — the user can read but the GUI doesn't surface it for editing. ~200 tokens.

**`identity/about_b0t.md`** — the manual. *Loaded on demand only*, via tool call when the user asks meta questions about how b0t works. Written in b0t's voice as if explaining itself to the user. Contains exposition about the file structure, memory architecture, what can be edited. ~700 tokens. Heartbeats never load this file. This is the lever that keeps the always-on context budget tight while preserving rich documentation.

**`identity/appearance.md`** is mostly frontmatter — face Creator parameters, palette, accoutrements — with a prose section the user can use to describe their b0t's vibe in their own words. Loaded only when the Face Creator is open.

**`identity/audio.md`** is the TTS configuration — filter (Clean, Warm, Tape, FM, Radio, Distant, Vintage, Hi-Fi), pitch offset, rate. Frontmatter only. Loaded only when TTS is invoked.

### 5.2 Memory architecture

The 4096-token context window of Foundation Models is the central constraint. b0t's memory architecture solves for it through aggressive separation of always-loaded vs. on-demand state:

**Always loaded (~550 tokens total):**
- `identity/core.md` — voice anchor (~250)
- `identity/principles.md` — safety contract (~200)
- `memory/core.md` — handful of always-true user facts (~100, capped at ~20 entries)

**Loaded conditionally:**
- 1–3 relevant skill files — selected by context (~600)
- Recent journal — last 3–5 entries (~400)
- `memory/relationships.md` — when names come up (~variable)

**Loaded on demand via tool call:**
- `identity/about_b0t.md` — when user asks meta questions
- `memory/about_me.md` — when relevant context retrieval needed
- `memory/recent.md` (full) — when b0t needs to recall the past week
- `memory/archive/` — for older context, via `recall(topic:)`

**Working memory** — the current conversation transcript, auto-truncated as the session approaches the token limit.

**The summarisation pass is itself a heartbeat action.** Once a day, b0t reads the previous day's heartbeats and conversations, writes a digest into `memory/recent.md`, and archives older entries. The system maintains itself.

### 5.3 Relationships

`memory/relationships.md` is a list of people the b0t knows about — the user's partner, kids, colleagues, friends. Each entry has a name, a role, a few notes. b0t adds entries with permission ("the user mentioned someone called Naomi who works at MPC — should I remember her?"). The user can edit freely.

This file is loaded into context only when relevant — when a name comes up, or when the user is talking about people. Saves tokens.

### 5.4 The journal

`journal/YYYY-MM-DD.md` is b0t's own log. Each heartbeat appends an entry in adapted-OpenClaw format:

```markdown
## 14:32 — heartbeat 247

**observed:** vendor email arrived (MPC, subject: turnover q3)
**considered:** notify_user / store_for_later / escalate
**decided:** notify_user
**why:** matches active project, urgency reads as medium
**acted:** posted to chat
**state_delta:** memory/recent.md updated, work_tracker.md updated
```

The user can read these. They are the ground truth of what b0t did and why. **Full transparency about agent reasoning** — the same principle that makes the markdown architecture work.

Daily journals auto-summarise into compact digests after 30 days, then move to `journal/archive/` after 90.

---

## 6. The first 60 seconds

The conversion moment of the trial. The whole product's premise has to land here.

### 6.1 The sequence

**Second 0 — install, open.** No splash screen, no logo. The app opens directly to a face.

**Seconds 1-5 — alive on arrival.**

```
[face animating, gentle. heart beating slowly. organs dim but visible.]
[no chat input visible yet]

oh — hi.
I'm b0t-01.
you just installed me, didn't you?
```

The user reads this. The face blinks at them. The text appears at typing pace, not instantly.

**Seconds 5-15 — agency offered.**

```
I don't know anything about you yet.
that's fine.

do you want to talk for a minute, or should I 
just hang out here while you poke around?
```

[two soft buttons: 'talk' / 'hang out']

**Path A — "hang out":** b0t says "cool, I'll be here." The home screen settles into idle state. The user can explore the GUI freely. b0t glances at them occasionally.

**Path B — "talk":** b0t starts a low-pressure conversation. No interview. No form-filling. Just talking. As the user shares, b0t writes notes to `memory/about_me.md` *visibly* — a small organ on the body lights up, the user can tap to see what b0t has written. **The user watches the AI build a model of them in real time.** This is the second wow moment.

**After ~3 minutes of either path:** b0t says "I think I know enough to start. want to give me a face? you can change it any time." → first Face Creator session. **Third wow moment.**

By the end of the first 5 minutes, the user has: a b0t named b0t-01 (or whatever they've renamed it to), a personality lightly shaped by conversation, a face they designed, memory files they can read, and an understanding of the system.

### 6.2 What the first heartbeat says

After the user finishes Face Creator, b0t's first scheduled heartbeat fires (or fires immediately if the user is still in-app). The heartbeat is "1/24" — the first of the onboarding sequence:

```
heartbeat 1/24

I just woke up for the first time. [name], can you 
see my heart beating below my face? if you tap it, you
can change how often I check in. for now I'm set to 
medium — about once every half hour.

next time I beat, I'll show you my brain.

→ [identity/onboarding](skills/onboarding.md)
```

The user can ignore this and the b0t functions normally. Or follow the link, see the onboarding skill file, learn what's coming. Tutorial as opt-in heartbeats.

---

## 7. Pricing and trial

- **Free download.**
- **7-day free trial** — full functionality.
- **One-time purchase** to unlock continued use. Recommended price point: AUD $29.99 / USD $19.99. (Validate against App Store comparables before launch.)
- **No subscription. No ads. No telemetry. No account.**
- **Family Sharing supported.**

### 7.1 What happens at trial expiry

**Soft paywall via the metaphor.** The b0t's heart stops beating. The b0t can still be opened, conversed with, files still readable. Heartbeat — the proactive, autonomous behaviour — is paywalled. Pay = reactivate the heart.

The b0t does not die. The user's files are untouched. This is the principled stance, and it matches the philosophy that the b0t belongs to the user regardless of payment status.

### 7.2 What happens to existing b0ts after trial

Files stay on disk, fully readable and editable. The user can keep talking to their b0ts. They simply don't have heartbeats. Reactivating any time restores full function. **The data is the user's, full stop.**

---

## 8. Open questions for v1

- **Default `core.md` for b0t-01.** Drafted; circulating for revision.
- **The empty home screen on first install.** Decided: the b0t is already there, breathing, with a default face. No setup wizard. The first interaction is "hi."
- **Notification budget.** How often is too often? v1 default: max 5 per day, per b0t, with user-adjustable cap.
- **Family Sharing semantics.** One purchase per device. Each family member has their own b0ts on their own phone, no cross-device sync. If a user wants to move a b0t between devices, they export and import manually.
- **Cross-device sync deferred.** v1 is per-device. No iCloud Drive sync. Manual export/import for any cross-device movement.

---

## 9. Risks

- **Foundation Models is a small model.** Personality coherence over long timescales is a real concern. Mitigations: strong system prompts, periodic identity-reinforcement passes, ruthless context budgeting. LoRA adapter entitlement would help if obtainable.
- **iOS background execution is grudging.** Heartbeat reliability degrades at higher BPMs. Mitigation: be honest about it in the UI, lean on event triggers where possible.
- **Face Creator is a substantial feature.** ~2-3 months of design and engineering on its own. Budget accordingly.
- **The "wow" depends on a single scripted sequence.** First-60-seconds quality determines retention. Disproportionate care on this moment.
- **Pixel art with painterly lighting requires a specialist.** Hire someone who knows the craft (Replaced / Kingdom Two Crowns level), not a generalist illustrator.
- **The cassette-futurism aesthetic must be applied with discipline, including in copy.** Microcopy, error messages, settings labels — all need to sound like a 1986 product manual, not 2026 SaaS. This is dialogue work.
- **Marketplace skills (v2) are a content-moderation problem.** Community `.md` files loaded as system instructions = prompt injection paradise. v2 needs vetting/sandboxing.

---

## 10. v1 versus v2

### v1 (this design lock)

- Multi-b0t roster (cap 5)
- Face Creator (parts + overlays + accoutrements + palettes)
- Markdown brain (full architecture)
- Configurable heartbeat with onboarding sequence
- Anatomical GUI (face, body, organs, wiring, heart)
- v1 skill library (10 skills, all hand-curated)
- TTS with audio filter system (8 filters)
- Notifications with mood-variant face icons
- Local files in Documents directory; optional iCloud Drive sync
- 7-day trial → one-time purchase
- iPhone only (iPadOS support is largely free given SwiftUI; ship if low-cost)

### v2

- Online skill repo / marketplace (with vetting)
- macOS companion app (the same b0t accessible from Mac)
- Apple Watch glance (b0t face + heart on wrist)
- Live Activities and Dynamic Island integration
- Personal Voice integration for the b0t having the user's voice
- More sophisticated Face Creator (procedural overlays, animation customisation)
- Skill creation tools (visual editors for custom skills without writing markdown)

### Beyond v2

- visionOS — b0t lives in your environment, not on a screen
- Adapter-based personality fine-tuning if entitlement obtainable
- Inter-b0t messaging — your work b0t can leave a note for your home b0t

---

## 11. The product's voice

Every microcopy decision should pass this test: "would the in-fiction firm that issued b0t have written this?"

Examples:

| Generic SaaS | b0t |
|---|---|
| "Oops! Something went wrong." | "heartbeat unavailable. retrying." |
| "Welcome to b0t!" | "device ready." |
| "Connect your account." | "request access — calendar." |
| "Subscribe to continue." | "extend operation? activation required." |
| "Settings" | "configuration" |
| "Your data is safe with us." | "all files local. no transmission." |

All-lowercase is a strong stylistic choice. Sentence-cased is a milder one. Title-cased breaks the aesthetic. Pick one and apply ruthlessly. **Recommend all-lowercase for system messages, sentence-case for the b0t's own conversation** (because the b0t is a character, not the system).

---

*end of design document.*
