---
description: Run the b0tKit Swift package test suite
---

Run all `b0tKit` package tests via SwiftPM.

Run:
```
swift test --package-path b0tKit
```

Report passing/failing tests. Do NOT silence failing tests by skipping them — surface them and propose investigation.

For UI/snapshot tests against the app target (Phase 4+), use `xcodebuild test` against the app's test scheme instead. Phase 0 only ships package tests.
