# default-bot

This directory is the canonical b0t that ships with the app on first install. The user's first b0t (`b0t-01`) is created by copying this entire directory tree into `~/Documents/b0ts/b0t-01/` on first launch.

Treat this directory as a real b0t. The structure here is what users see in their Documents folder. Editing files here changes the shipped default. New b0ts created by the user are produced by re-copying this template (with a fresh serial number, randomised default face, and empty memory).

## Structure

```
default-bot/
├── identity/
│   ├── core.md            # voice anchor — always loaded
│   ├── principles.md      # safety contract — always loaded, mutable: false
│   ├── about_b0t.md       # the manual — loaded on demand
│   ├── appearance.md      # face params and aesthetic notes
│   └── audio.md           # TTS filter and pitch
├── memory/
│   ├── core.md            # always loaded, ~20 entries cap
│   ├── about_me.md        # loaded on demand
│   ├── relationships.md   # loaded when names come up
│   ├── recent.md          # rolling 7-day digest, loaded on demand
│   └── archive/           # older digests
├── skills/
│   ├── calendar.md        # canonical skill template
│   ├── mail.md
│   ├── reminders.md
│   ├── health.md          # disabled by default
│   ├── location.md
│   ├── notes.md           # disabled by default (Shortcuts fallback)
│   ├── weather.md
│   ├── time-awareness.md
│   ├── journaling.md
│   └── onboarding.md      # 24-beat tutorial
├── heartbeat/
│   ├── schedule.md        # BPM, quiet hours, triggers
│   └── actions.md         # what each beat does
├── journal/               # populated at runtime, empty in the template
└── face/                  # face composition (populated from Face Creator output)
```

## File frontmatter conventions

All files use YAML frontmatter for parameters and prose for behaviour. Keys used across files:

- **`mutable: true|false`** — whether the GUI surfaces this file for editing. `false` means GUI-locked; the file is still editable in any text editor.
- **`always_in_context: true|false`** — whether the ContextAssembler always loads this file into the model's prompt.
- **`load_on_demand: true|false`** — whether the file is loaded only via tool call.
- **`load_when: <description>`** — human-readable hint describing the trigger condition.
- **`enabled: true|false`** — whether a skill is active.
- **`permission: <kind>`** — system permission required (calendar, mail, health, etc.).
- **`skill_id: <slug>`** — for skill files, the ID the skill registry matches against.

## Editing the default

Changes to files here ship in the next app build. Be aware:

- Voice changes in `identity/core.md` affect *every* new b0t users create. Test that the voice feels right by reading several files in sequence.
- Skill changes affect new b0ts. Existing user b0ts retain their version of the skill files until the user explicitly updates.
- Adding a new skill requires adding both the `.md` file here and a corresponding Swift bridge in `b0tKit/b0tSkills/`. New skills require new permissions; permission flow needs to be added to onboarding.

## Migration

When the default b0t structure changes (new files added, frontmatter keys renamed, file paths moved), existing user b0ts need to be migrated. v1 strategy:

- New files in `default-bot/` are added to existing b0ts on app update with default content.
- Renamed or moved files require a migration script in `b0tBrain` that runs on app update.
- Frontmatter key renames are handled with backward compatibility (read both old and new keys; write new only).

Document migrations in `docs/decisions/` when they're substantial.
