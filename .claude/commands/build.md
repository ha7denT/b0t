---
description: Build the b0t app to the default iOS simulator
---

Build the b0t app target for an available iOS simulator and report the result.

Run:
```
xcodebuild -project b0t.xcodeproj -scheme b0t -sdk iphonesimulator -destination "generic/platform=iOS Simulator" build
```

If `generic/platform=iOS Simulator` is rejected by xcodebuild, fall back to a specific iPhone simulator from `xcrun simctl list devices available`. On success, summarise (target, sdk, time). On failure, surface the first compile error and propose a fix — do not auto-apply unless the user asked you to.
