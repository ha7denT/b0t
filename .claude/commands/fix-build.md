---
description: Build with reasoning — diagnose any failure and propose a fix
---

Run a clean build of the b0t app target. If it fails:

1. Read the full xcodebuild output (do not truncate prematurely).
2. Identify the first root-cause error (often the topmost compile error; ignore cascade errors below it).
3. Read the relevant source file(s) at the cited line(s).
4. Cross-reference with `docs/prd.md` and the relevant module's `CLAUDE.md` to ensure any fix preserves the intended design.
5. Propose a minimal fix and apply it with the user's confirmation.
6. Re-run the build.

Do not silently lower warning-as-error settings, disable strict concurrency, or add `@available` checks for OSes below iOS 26.
