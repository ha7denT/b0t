---
description: Audit the codebase for App Store submission readiness
---

Audit pass — produce a punch list of remaining work for App Store submission. Check, in order:

1. **Privacy manifest:** `PrivacyInfo.xcprivacy` declares zero tracking, zero collected data, zero linked data.
2. **No network calls** outside of explicitly user-initiated flows. Grep for `URLSession`, `Alamofire`, `WebKit`, `URLRequest`. If any exist, surface them.
3. **No third-party SDK that phones home.** Review every entry in `Package.resolved`.
4. **Voice-and-copy guide compliance.** Sample 20 user-facing strings, verify each conforms to `docs/references/voice-and-copy-guide.md`.
5. **Accessibility:** every interactive element has a label, Dynamic Type works, reduce-motion respected.
6. **Performance:** frame rate during home idle = 60fps on iPhone 16 Pro.
7. **Memory:** app idle < 150MB.
8. **IAP flow:** trial → purchase → restore → Family Sharing all tested.
9. **App Store metadata:** screenshots, description, keywords drafted and reviewed against voice guide.

Report findings as a checklist with severity per item: blocker / nice-to-have / done.
