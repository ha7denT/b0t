# b0tCore

The Foundation Models loop. Owns the lifecycle of `LanguageModelSession` instances, the `ContextAssembler`, and the `@Generable` decision types that the model returns.

## Public API contracts (target shape)

- `ContextAssembler` — assembles a prompt from b0tBrain files, staying under the 4096-token budget. See PRD §3.4 and `docs/specs/context-assembler.md` (forthcoming).
- `LanguageModelSession` wrapper — short-lived; never retained across user turns.
- `@Generable` types: `TickDecision`, `ConversationResponse`, `MemoryObservation`, `RelationshipNote`, `MoodTransition`. See PRD §5.2.
- `HeartbeatManager` — registers `BGAppRefreshTask`, runs ticks, writes journal entries. See PRD §5.6.

## Patterns

- Every model call is a fresh session with assembled context. State persists in markdown files (`b0tBrain`), not in session memory.
- Token counts are *measured*, not estimated. Every assembled context logs its size in debug builds.
- On `.exceededContextWindowSize`, fall back to a digest assembly and surface the event to the user via the b0t.

## Depends on

- `b0tBrain` (markdown reads/writes)

## Does NOT depend on

- `b0tFace`, `b0tAudio`, `b0tDesign` (UI/output concerns belong in the app target or face/audio packages)

## Read first when working here

- `docs/prd.md` §3.3, §3.4, §5.2, §5.6
- ADR 0001 (on-device only), ADR 0005 (three-file identity)
