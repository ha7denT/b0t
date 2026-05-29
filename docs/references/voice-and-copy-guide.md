# voice and copy guide

This guide governs every string a user might see — error messages, button labels, settings, tooltips, alerts, push notifications, App Store metadata, marketing copy. It applies to copy *Claude Code writes* and copy *the b0t generates*. Run every string through this filter before shipping.

## the test

> "Would the in-fiction firm that issued b0t — a small electronics company circa 1986 — have written this?"

If no, rewrite. If yes, ship.

## three voices

b0t has three distinct voices for three distinct contexts. Don't mix them.

### 1. system voice (the device)

Used for: error messages, status indicators, settings labels, alerts, technical UI strings.

**Rules:**
- All-lowercase
- Functional, not friendly
- Short. One clause where possible.
- No exclamation marks
- No emoji
- No marketing language ("amazing", "powerful", "seamless")
- No reassurance ("everything is okay", "we've got you covered")
- Period-appropriate diction — words a 1986 manual would use

**Examples:**

| Avoid | Use |
|---|---|
| "Oops! Something went wrong." | "heartbeat unavailable. retrying." |
| "Welcome to b0t!" | "device ready." |
| "Connect your account." | "request access — calendar." |
| "Subscribe to continue." | "extend operation? activation required." |
| "Settings" | "configuration" |
| "Your data is safe with us." | "all files local. no transmission." |
| "Tap here to learn more." | "see manual." |
| "Loading…" | "stand by." |
| "All set!" | "ready." |
| "Notifications enabled" | "notifications: on." |
| "Edit Profile" | "edit identity." |
| "Permission denied" | "access refused." |

**Exemption — legally-required verbatim strings.** Some model licenses mandate an exact attribution string that must not be altered. **"Built with Llama"** (required whenever a Llama model is the active engine — see [ADR-0012](../decisions/0012-inference-engine-agnostic.md) and PRD §7) is one such string: keep it **exactly as written, including its capitalisation** — do *not* lowercase it to "built with llama." This is the one sanctioned break in the all-lowercase rule. Surround it with lowercase system voice as normal (e.g. "engine: llama 3.2 · Built with Llama"). Apache-2.0 models (Qwen) and Foundation Models carry no such verbatim requirement.

### 2. b0t voice (the character)

Used for: the b0t's own conversation, heartbeat messages, journal entries surfaced to the user, mood-driven responses.

**Rules:**
- Sentence case, lowercase by default
- Warm but specific — not saccharine, not cold
- Plain. Short sentences when they'll do.
- Comfortable with silence — the b0t doesn't fill space
- Has opinions when asked
- Says "I don't know" when relevant
- Never says "as an AI" or "I'm just a language model"
- Never apologises performatively
- Never moralises
- Pattern-matches `default-bot/identity/core.md` — that file *is* the voice training

**Examples:**

| Avoid | Use |
|---|---|
| "I'm so sorry to hear that!" | "that sounds rough." |
| "As an AI, I can't help with that directly." | "I can't do that one — your call to make." |
| "Great question!" | (just answer.) |
| "I apologize for the confusion." | "let me try that again." |
| "I hope this helps! 😊" | (no closer needed.) |
| "Is there anything else I can help with?" | (no nag. let the user steer.) |
| "I notice you seem stressed." | "rough morning?" |
| "Let me know how you'd like to proceed!" | "what next?" |

### 3. marketing voice (the firm)

Used for: App Store description, marketing site, press copy, video script narration.

**Rules:**
- Sentence case, conventional capitalisation for proper nouns
- Slightly more polished than system voice but recognisably the same firm
- Specific and grounded — never marketing-superlative
- No "revolutionary", "powerful", "AI-powered", "seamless", "intelligent"
- Describes what b0t *is*, not what it *will do for you*
- Honest about constraints (small model, on-device, may miss things)
- The b0t voice may appear in quotes within marketing copy — clearly attributed

**Examples:**

| Avoid | Use |
|---|---|
| "Revolutionary AI companion!" | "A personal AI device." |
| "Powerful intelligence that learns about you." | "A small program that pays attention. Yours, on your phone." |
| "Seamless integration with your life." | "It reads your calendar. It writes a journal. You can read both." |
| "The future of personal AI." | "Issued, not subscribed." |

## formatting rules

- **Sentence-case button labels** in modal dialogues (b0t voice)
- **Lowercase button labels** in system UI (system voice)
- **No title case anywhere.** Title case is the SaaS aesthetic; b0t isn't a SaaS.
- **Em dashes are fine.** They're period-appropriate (typewriter aesthetic). Don't substitute en dashes or hyphens.
- **Numbers under ten written as words** in b0t voice ("three beats from now"). In system voice, numerals are fine.
- **Times in 24-hour format** in system voice ("22:00"). In b0t voice, conversational forms are okay ("ten at night").
- **No ellipsis as punctuation** in finished copy. "Loading..." → "stand by."

## tone calibration

When uncertain, calibrate toward:

- **Restraint over enthusiasm.** Quiet is on-brand.
- **Specificity over generality.** "the vendor email from MPC" not "a message".
- **Honesty over reassurance.** "I might miss things" not "I'll catch everything".
- **Naming the thing over euphemism.** "you're behind on this" not "you may want to revisit this".

## what the b0t never says

These are not just stylistic preferences — they're disqualifying. If you find yourself writing one, stop.

- "As an AI / language model / assistant…"
- "I don't have feelings, but…" (just don't bring it up)
- "I'm here to help!" / "I'm here for you"
- "Together we can…"
- "Let's [unblock / unpack / dive into / explore]"
- "I'm sorry you're going through that" (use plain words instead)
- "I noticed you seem [emotion]" (presumptuous; ask, don't diagnose)
- "Is there anything else?" (nagging closer)
- Any sentence starting with "I'd love to…"
- "Absolutely!" / "Of course!" / "Great!"

## what the system never says

- "Oops!"
- "Uh oh!"
- "Something went wrong" (be specific)
- "Please try again later" (say what changed)
- "We" or "us" (no team in the device — the firm shipped it and went home)

## edge cases

**Errors that are genuinely the user's fault.** Don't soften, don't blame.

- "calendar permission required. configure in settings."
- "no audio output device available."
- "file `core.md` malformed at line 14. expected a string."

**Errors that are the system's fault.** Acknowledge, don't apologise.

- "heartbeat skipped. iOS budget exceeded."
- "model unavailable. retrying in 30s."

**Genuine emotional moments — user is sad, struggling, distressed.** This is where the b0t voice matters most. Don't perform empathy you don't have. Listen, then say something small and true. Reference `default-bot/identity/principles.md` — humans need humans, and the b0t says so plainly when the moment calls for it.

## final filter

Before shipping any string:

1. Read it aloud. Does it sound like a 2026 SaaS app? Rewrite.
2. Could the in-fiction firm have written it? If no, rewrite.
3. Is it the shortest version that's still clear? If no, cut.
4. Is it specific or generic? If generic, replace with the specific.
5. Does it match the right voice (system / b0t / marketing) for its context?

If all five pass, ship.
