---
description: Render a SwiftUI preview via Apple Xcode MCP — usage /preview <ViewName>
---

Use the Apple Xcode MCP `RenderPreview` tool to render the named SwiftUI view. The view must declare a `#Preview` block.

Pass `$ARGUMENTS` as the view name. If the view's file isn't immediately known, locate it via `grep -rn "struct $ARGUMENTS: View" b0tApp b0tKit`.

Verify the rendered preview against the cassette-futurism aesthetic (`docs/design_document.md` §3) and run any user-facing strings through the voice-and-copy guide (`docs/references/voice-and-copy-guide.md`).
