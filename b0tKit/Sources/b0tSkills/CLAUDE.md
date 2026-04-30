# b0tSkills

Capability bridges — typed Swift wrappers around system frameworks (EventKit, Mail, HealthKit, Core Location, etc.) exposed to the model as tool handles.

## Public API contracts (target shape)

- `Skill` protocol — `id`, `requiredPermissions`, `toolHandles`, `loadParameters(from:)`.
- `SkillRegistry` — maps `skill_id` (frontmatter) → registered Swift bridge.
- One bridge per v1 skill (10 skills, see PRD §4.2 / design doc §4.2).

## Patterns

- The .md file is prompt-and-behaviour; the Swift bridge is system access. **Users compose behaviours from existing primitives; new system permissions ship in app updates.** See design doc §4.1.
- Every permission requested at first-use, not at app launch. Skill is disabled in UI until granted.
- v1 ships exactly the skills in PRD §4.2 / design doc §4.2 — no more, no fewer.

## Depends on

- `b0tBrain` (reads skill `.md` parameters)

## Read first when working here

- `docs/prd.md` §5.3
- `docs/design_document.md` §4
- `default-bot/skills/` — the shipped skill files
