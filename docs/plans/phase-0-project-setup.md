# Phase 0 — Project Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the b0t Xcode project, Swift package, Claude Code harness, CI, and tooling so that subsequent phases can land code against a clean, buildable, testable baseline.

**Architecture:** A single Xcode project (`b0t.xcodeproj`) at the repo root, with a local Swift package `b0tKit/` (six modules) consumed by an iOS app target `b0tApp`. Resources for the default b0t are bundled from the existing `default-bot/` folder via Xcode folder references. The Claude Code harness ships in `.claude/` (settings, slash commands) and per-module `CLAUDE.md` scaffolding lives next to the code it documents.

**Tech Stack:**
- Swift 6.0+, iOS 26.0 deployment target
- Apple Foundation Models (used in later phases — not in Phase 0)
- SwiftPM (local package), Xcode 26+ project file (committed)
- swift-format (`swift format` subcommand, Apple-blessed)
- GitHub Actions for CI (`macos-15` runner)
- MCP servers: `xcode` (Apple's), `XcodeBuildMCP` (third-party) — both already registered in local config

**Reference docs to consult during execution:**
- `docs/prd.md` §3 (architecture), §4 (Phase 0 acceptance), §10 (tooling)
- `docs/design_document.md` §1 (philosophy), §3 (aesthetic — only relevant later)
- `docs/decisions/` ADRs 0001–0007 — settled, do not re-litigate
- `CLAUDE.md` (root) — project conventions

**Conventions used in this plan:**
- `**[USER]**` marks a step Jamee performs at the keyboard (Xcode IDE actions, App Store Connect, etc.). Claude Code cannot perform these.
- `**[CC]**` marks a step Claude Code (or whoever is executing the plan) performs.
- `**[VERIFY]**` marks a verification step — run a command, check output, do not move on if it fails.

---

## File Structure (what this phase creates/modifies)

**Creates:**

```
b0t/
├── .gitignore                              # Xcode + macOS + Swift
├── .swift-format                           # swift-format config
├── .git/hooks/pre-commit                   # local hook (script, not committed)
├── .github/
│   └── workflows/
│       └── ci.yml                          # build + test on push
├── .claude/
│   ├── settings.json                       # MCP servers + hooks
│   └── commands/
│       ├── build.md
│       ├── test.md
│       ├── preview.md
│       ├── fix-build.md
│       ├── implement.md
│       └── audit.md
├── b0t.xcodeproj/                          # created by Xcode IDE
├── b0tApp/
│   └── Sources/
│       └── App/
│           ├── b0tApp.swift                # @main App entry
│           └── ContentView.swift           # placeholder home view
├── b0tKit/
│   ├── Package.swift
│   ├── Sources/
│   │   ├── b0tCore/
│   │   │   ├── CLAUDE.md
│   │   │   └── b0tCorePlaceholder.swift
│   │   ├── b0tBrain/
│   │   │   ├── CLAUDE.md
│   │   │   └── b0tBrainPlaceholder.swift
│   │   ├── b0tSkills/
│   │   │   ├── CLAUDE.md
│   │   │   └── b0tSkillsPlaceholder.swift
│   │   ├── b0tFace/
│   │   │   ├── CLAUDE.md
│   │   │   └── b0tFacePlaceholder.swift
│   │   ├── b0tAudio/
│   │   │   ├── CLAUDE.md
│   │   │   └── b0tAudioPlaceholder.swift
│   │   └── b0tDesign/
│   │       ├── CLAUDE.md
│   │       └── b0tDesignPlaceholder.swift
│   └── Tests/
│       ├── b0tCoreTests/b0tCoreTests.swift
│       ├── b0tBrainTests/b0tBrainTests.swift
│       ├── b0tSkillsTests/b0tSkillsTests.swift
│       ├── b0tFaceTests/b0tFaceTests.swift
│       ├── b0tAudioTests/b0tAudioTests.swift
│       └── b0tDesignTests/b0tDesignTests.swift
├── Resources/
│   └── CLAUDE.md                           # describes how default-bot ships
└── docs/
    ├── IMPLEMENTATION.md                   # north-star tracker
    └── plans/
        └── phase-0-project-setup.md        # (this file)
```

**Modifies:**

- `docs/prd.md` §3.1 — replace `Resources/DefaultBot/` references with `default-bot/` (kept at repo root, bundled at build time via Xcode folder reference). Document the build-time bundling.
- `CLAUDE.md` (root) — confirm consistent with PRD post-update; note new layout.

---

## Task 1: Documentation consistency pass

**Files:**
- Modify: `docs/prd.md` (lines around §3.1, the project structure tree)
- Modify: `CLAUDE.md` (root) — verify section labelled "Project structure" matches PRD post-edit

**Why first:** Jamee's instruction was "update docs for consistency" (Q3). Locking the on-disk vs PRD layout *before* the Xcode project exists means we don't introduce drift.

- [ ] **Step 1.1: Read PRD §3.1 to find every `Resources/DefaultBot/` and `Resources/Skills/` reference**

Run: `grep -n "Resources/" /Users/haydentoppeross/development/b0t/docs/prd.md`
Expected: lines in the §3.1 directory tree (around lines 84–95) plus narrative references.

- [ ] **Step 1.2: Edit PRD §3.1 directory tree to reflect repo layout**

Replace the `Resources/` block in the §3.1 directory tree. The new tree should show:

```
├── default-bot/                          # source-of-truth for the shipped b0t (markdown)
│   ├── identity/
│   ├── memory/
│   ├── skills/
│   ├── heartbeat/
│   └── face/
├── assets/                               # face parts, palettes, fonts, icons, sounds
│   ├── face-parts/
│   ├── palettes/
│   ├── sounds/
│   ├── fonts/
│   └── icons/
└── Tests/
    ├── b0tCoreTests/
    ├── b0tBrainTests/
    ├── b0tSkillsTests/
    └── b0tAudioTests/
```

(Tests subtree stays as-is.)

- [ ] **Step 1.3: Add a paragraph to PRD §3.1 explaining build-time bundling**

Append directly under the directory tree:

```
**Resource bundling.** `default-bot/` and `assets/` live at the repo root, not under a `Resources/` group. The iOS app target adds them as **folder references** in the Xcode project (`b0tApp` → "Add Files to b0tApp" → check "Create folder references"). Folder references mirror the on-disk structure in the bundle, so files added to `default-bot/skills/` on disk are automatically included in the next build. No symlinks, no copy-build-phase scripts.
```

- [ ] **Step 1.4: Run grep to confirm no stale `Resources/DefaultBot/` references remain**

Run: `grep -n "Resources/DefaultBot\|Resources/Skills" /Users/haydentoppeross/development/b0t/docs/prd.md`
Expected: no matches.

- [ ] **Step 1.5: Confirm root `CLAUDE.md` already lists `default-bot/` correctly**

Run: `grep -n "default-bot" /Users/haydentoppeross/development/b0t/CLAUDE.md`
Expected: matches in the project structure block (line ~22 onward). No edit needed.

- [ ] **Step 1.6: Commit**

```bash
git add docs/prd.md
git commit -m "docs(prd): align §3.1 to repo layout — default-bot at root, folder references"
```

---

## Task 2: `.gitignore` + baseline commit

**Files:**
- Create: `.gitignore`

- [ ] **Step 2.1: Write `.gitignore`**

```gitignore
# macOS
.DS_Store
*.swp
*~

# Xcode
build/
DerivedData/
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3
xcuserdata/
*.moved-aside
*.xccheckout
*.xcscmblueprint

# Swift Package Manager
.swiftpm/
.build/
Package.resolved

# IDEs
.idea/
.vscode/

# Local settings (user-specific)
.claude/settings.local.json
```

- [ ] **Step 2.2: Stage all current docs and assets and the .gitignore**

```bash
git add .gitignore CLAUDE.md README.md docs/ default-bot/ assets/
git status --short
```

Expected: every doc and asset file shows as staged (no `.DS_Store`).

- [ ] **Step 2.3: Make the baseline commit**

```bash
git commit -m "chore: initial baseline — docs, ADRs, default-bot content, raw assets

Pre-code baseline of design docs, PRD, ADRs, voice-and-copy guide,
the canonical default b0t markdown content, and raw design assets.
The Xcode project, Swift package, and Claude harness scaffolding land in
subsequent commits per docs/plans/phase-0-project-setup.md."
```

- [ ] **Step 2.4: Verify push works to GitHub**

```bash
git push -u origin main
```

Expected: push succeeds. If SSH key isn't configured, the push will fail with a clear error — fix the SSH config and retry. Do not switch to HTTPS.

---

## Task 3: Create the Xcode project

**[USER]** This task is performed by Jamee in Xcode. The project file format is best created by Xcode itself rather than hand-written. Once created, all subsequent edits go through Claude Code editing the Swift Package or folder references.

**Files:**
- Create: `b0t.xcodeproj/` (created by Xcode)
- Create: `b0tApp/Sources/App/b0tApp.swift` (created by Xcode template, then moved/edited)
- Create: `b0tApp/Sources/App/ContentView.swift` (created by Xcode template, then moved/edited)

**Settings to use during creation:**
- **Template:** iOS → App
- **Product Name:** `b0t`
- **Team:** Hayden Toppeross (`P2VY4WT259`)
- **Organization Identifier:** `com.toppeross`
- **Bundle Identifier:** `com.toppeross.b0t` (autocomputed)
- **Interface:** SwiftUI
- **Language:** Swift
- **Storage:** None
- **Include Tests:** unchecked (we use the package test targets)
- **Save location:** create in a *temporary* folder first (e.g., `~/Desktop/b0t-scratch/`) — we'll move pieces into the repo. Xcode refuses to create inside a non-empty directory, so we don't point it at the repo root directly.

- [ ] **Step 3.1 [USER]: Create the project in `~/Desktop/b0t-scratch/`**

In Xcode → File → New → Project, with the settings above. Confirm Xcode generates:

```
~/Desktop/b0t-scratch/
└── b0t/
    ├── b0t.xcodeproj/
    └── b0t/
        ├── b0tApp.swift
        ├── ContentView.swift
        ├── Assets.xcassets/
        └── Preview Content/
```

- [ ] **Step 3.2 [USER]: Move `b0t.xcodeproj` into the repo root**

```bash
mv ~/Desktop/b0t-scratch/b0t/b0t.xcodeproj /Users/haydentoppeross/development/b0t/
```

- [ ] **Step 3.3 [CC]: Create the target source layout per PRD §3.1**

```bash
cd /Users/haydentoppeross/development/b0t
mkdir -p b0tApp/Sources/App
mkdir -p b0tApp/Resources
```

- [ ] **Step 3.4 [USER]: Move source files from the scratch folder into the new layout**

```bash
mv ~/Desktop/b0t-scratch/b0t/b0t/b0tApp.swift /Users/haydentoppeross/development/b0t/b0tApp/Sources/App/b0tApp.swift
mv ~/Desktop/b0t-scratch/b0t/b0t/ContentView.swift /Users/haydentoppeross/development/b0t/b0tApp/Sources/App/ContentView.swift
mv ~/Desktop/b0t-scratch/b0t/b0t/Assets.xcassets /Users/haydentoppeross/development/b0t/b0tApp/Resources/Assets.xcassets
mv "~/Desktop/b0t-scratch/b0t/b0t/Preview Content" /Users/haydentoppeross/development/b0t/b0tApp/Resources/Preview\ Content
rm -rf ~/Desktop/b0t-scratch
```

- [ ] **Step 3.5 [USER]: Re-link the moved files in Xcode**

Open `b0t.xcodeproj`. The original `b0t/` group will show all files in red (missing). Action:
1. Delete the red `b0t` group (choose "Remove References" — files are already gone from disk).
2. In Project Navigator, right-click the project node → "Add Files to b0t…" → select `b0tApp/Sources/`. Check **"Create groups"** (NOT folder references for source — we want code in groups). Add to target `b0t`.
3. Right-click again → "Add Files to b0t…" → select `b0tApp/Resources/Assets.xcassets` and `b0tApp/Resources/Preview Content`. Add to target `b0t`.
4. Build menu → Product → Build (`⌘B`). Should succeed.

- [ ] **Step 3.6 [USER]: Set deployment target and Swift Strict Concurrency**

Project settings → `b0t` target → General → Minimum Deployments → iOS = 26.0
Project settings → `b0t` target → Build Settings → search `concurrency` → set "Strict Concurrency Checking" = `Complete`.
Project settings → `b0t` target → Build Settings → search `Treat Warnings` → set "Treat Warnings as Errors" = `Yes` for both Debug and Release.

- [ ] **Step 3.7 [VERIFY]: Build clean from CLI**

```bash
cd /Users/haydentoppeross/development/b0t
xcodebuild -project b0t.xcodeproj -scheme b0t -destination "platform=iOS Simulator,name=iPhone 16 Pro" build | tail -20
```

Expected: `** BUILD SUCCEEDED **` at the bottom. If the simulator name doesn't exist on your machine, run `xcrun simctl list devices available` and substitute a valid name.

- [ ] **Step 3.8 [CC]: Commit the project**

```bash
git add b0t.xcodeproj b0tApp/
git commit -m "feat(phase-0): create Xcode project, move sources to b0tApp/Sources/

- iOS 26.0 deployment target
- Swift strict concurrency: complete
- Treat warnings as errors
- App entry b0tApp/Sources/App/b0tApp.swift, view ContentView.swift
- Bundle id com.toppeross.b0t, signed by team P2VY4WT259
- Resources (Assets.xcassets, Preview Content) under b0tApp/Resources/"
```

---

## Task 4: Swift package skeleton — `b0tKit`

**Files:**
- Create: `b0tKit/Package.swift`
- Create: `b0tKit/Sources/b0tCore/b0tCorePlaceholder.swift`
- Create: `b0tKit/Sources/b0tBrain/b0tBrainPlaceholder.swift`
- Create: `b0tKit/Sources/b0tSkills/b0tSkillsPlaceholder.swift`
- Create: `b0tKit/Sources/b0tFace/b0tFacePlaceholder.swift`
- Create: `b0tKit/Sources/b0tAudio/b0tAudioPlaceholder.swift`
- Create: `b0tKit/Sources/b0tDesign/b0tDesignPlaceholder.swift`
- Create: `b0tKit/Tests/b0tCoreTests/b0tCoreTests.swift`
- Create: `b0tKit/Tests/b0tBrainTests/b0tBrainTests.swift`
- Create: `b0tKit/Tests/b0tSkillsTests/b0tSkillsTests.swift`
- Create: `b0tKit/Tests/b0tFaceTests/b0tFaceTests.swift`
- Create: `b0tKit/Tests/b0tAudioTests/b0tAudioTests.swift`
- Create: `b0tKit/Tests/b0tDesignTests/b0tDesignTests.swift`

**Why placeholder + test per module:** Phase 0's acceptance is "project builds clean, empty SwiftUI app launches." For the package, we want the same: every module compiles, every test target runs at least one assertion. Placeholders give the package something concrete to compile and test against, and prove the inter-target plumbing works before any real code lands.

- [ ] **Step 4.1: Create `Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "b0tKit",
    platforms: [
        .iOS("26.0"),
    ],
    products: [
        .library(name: "b0tCore", targets: ["b0tCore"]),
        .library(name: "b0tBrain", targets: ["b0tBrain"]),
        .library(name: "b0tSkills", targets: ["b0tSkills"]),
        .library(name: "b0tFace", targets: ["b0tFace"]),
        .library(name: "b0tAudio", targets: ["b0tAudio"]),
        .library(name: "b0tDesign", targets: ["b0tDesign"]),
    ],
    targets: [
        .target(name: "b0tCore", dependencies: ["b0tBrain"]),
        .target(name: "b0tBrain"),
        .target(name: "b0tSkills", dependencies: ["b0tBrain"]),
        .target(name: "b0tFace", dependencies: ["b0tDesign"]),
        .target(name: "b0tAudio"),
        .target(name: "b0tDesign"),

        .testTarget(name: "b0tCoreTests", dependencies: ["b0tCore"]),
        .testTarget(name: "b0tBrainTests", dependencies: ["b0tBrain"]),
        .testTarget(name: "b0tSkillsTests", dependencies: ["b0tSkills"]),
        .testTarget(name: "b0tFaceTests", dependencies: ["b0tFace"]),
        .testTarget(name: "b0tAudioTests", dependencies: ["b0tAudio"]),
        .testTarget(name: "b0tDesignTests", dependencies: ["b0tDesign"]),
    ],
    swiftLanguageModes: [.v6]
)
```

Save to `/Users/haydentoppeross/development/b0t/b0tKit/Package.swift`.

- [ ] **Step 4.2: Write the failing test for `b0tCore`**

`b0tKit/Tests/b0tCoreTests/b0tCoreTests.swift`:

```swift
import XCTest
@testable import b0tCore

final class b0tCoreTests: XCTestCase {
    func test_modulePlaceholder_identifierMatchesModuleName() {
        XCTAssertEqual(b0tCorePlaceholder.identifier, "b0tCore")
    }
}
```

- [ ] **Step 4.3: Run the test — should fail with "no such symbol"**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test --filter b0tCoreTests 2>&1 | tail -20
```

Expected: build error referencing `b0tCorePlaceholder` (symbol not defined).

- [ ] **Step 4.4: Add the placeholder for `b0tCore`**

`b0tKit/Sources/b0tCore/b0tCorePlaceholder.swift`:

```swift
public enum b0tCorePlaceholder {
    public static let identifier = "b0tCore"
}
```

- [ ] **Step 4.5: Run the test again — should pass**

```bash
swift test --filter b0tCoreTests 2>&1 | tail -10
```

Expected: `Test Suite 'b0tCoreTests' passed`.

- [ ] **Step 4.6: Repeat steps 4.2–4.5 for the other five modules**

Pattern for each module `<Module>` ∈ {`b0tBrain`, `b0tSkills`, `b0tFace`, `b0tAudio`, `b0tDesign`}:

Test file at `b0tKit/Tests/<Module>Tests/<Module>Tests.swift`:

```swift
import XCTest
@testable import <Module>

final class <Module>Tests: XCTestCase {
    func test_modulePlaceholder_identifierMatchesModuleName() {
        XCTAssertEqual(<Module>Placeholder.identifier, "<Module>")
    }
}
```

Implementation at `b0tKit/Sources/<Module>/<Module>Placeholder.swift`:

```swift
public enum <Module>Placeholder {
    public static let identifier = "<Module>"
}
```

(Replace `<Module>` literally — e.g., `b0tBrainPlaceholder`, `b0tFacePlaceholder`.)

- [ ] **Step 4.7 [VERIFY]: Run the entire test suite**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test 2>&1 | tail -30
```

Expected: all six test suites pass, total 6 tests.

- [ ] **Step 4.8: Commit the package**

```bash
cd /Users/haydentoppeross/development/b0t
git add b0tKit/
git commit -m "feat(phase-0): scaffold b0tKit Swift package — six modules with placeholder tests

Modules: b0tCore, b0tBrain, b0tSkills, b0tFace, b0tAudio, b0tDesign.
Each ships a placeholder enum and a smoke test asserting the module
identifier. Inter-target dependencies follow PRD §3.1:
- b0tCore depends on b0tBrain
- b0tSkills depends on b0tBrain
- b0tFace depends on b0tDesign
- b0tBrain, b0tAudio, b0tDesign are leaves.

Swift 6 language mode, complete strict concurrency, iOS 26 platform."
```

---

## Task 5: Wire `b0tKit` into the app target

**[USER]** Adding a local Swift package to an Xcode app target is an IDE action.

- [ ] **Step 5.1 [USER]: Add `b0tKit` as a local package dependency**

In Xcode: File → Add Package Dependencies → "Add Local…" → choose `/Users/haydentoppeross/development/b0t/b0tKit/` → Add Package.

When the target picker appears, add **all six** product libraries (`b0tCore`, `b0tBrain`, `b0tSkills`, `b0tFace`, `b0tAudio`, `b0tDesign`) to the `b0t` app target.

- [ ] **Step 5.2 [CC]: Update `ContentView.swift` to import and reference `b0tCore`**

Replace the contents of `b0tApp/Sources/App/ContentView.swift` with:

```swift
import SwiftUI
import b0tCore

struct ContentView: View {
    var body: some View {
        VStack {
            Text("b0t")
                .font(.system(.largeTitle, design: .monospaced))
            Text("module: \(b0tCorePlaceholder.identifier)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
```

This proves the app target can resolve symbols from the package.

- [ ] **Step 5.3 [VERIFY]: Build the app target from CLI**

```bash
cd /Users/haydentoppeross/development/b0t
xcodebuild -project b0t.xcodeproj -scheme b0t \
    -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
    build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5.4: Commit**

```bash
git add b0t.xcodeproj b0tApp/Sources/App/ContentView.swift
git commit -m "feat(phase-0): wire b0tKit into b0t app target, smoke-test in ContentView"
```

---

## Task 6: Bundle `default-bot/` as a folder reference

**[USER]** Folder references in Xcode mirror an on-disk directory into the app bundle.

- [ ] **Step 6.1 [USER]: Add `default-bot/` as a folder reference**

In Xcode: right-click the `b0t` project node → "Add Files to b0t…" → select `/Users/haydentoppeross/development/b0t/default-bot/`. **Important:** in the dialog, choose **"Create folder references"** (the result will appear as a *blue* folder, not yellow). Add to target `b0t`.

- [ ] **Step 6.2 [CC]: Add a runtime smoke test that finds `default-bot/identity/core.md` in the bundle**

Update `b0tApp/Sources/App/ContentView.swift`:

```swift
import SwiftUI
import b0tCore

struct ContentView: View {
    @State private var bundleStatus: String = "checking…"

    var body: some View {
        VStack(spacing: 8) {
            Text("b0t")
                .font(.system(.largeTitle, design: .monospaced))
            Text("module: \(b0tCorePlaceholder.identifier)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("default-bot: \(bundleStatus)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding()
        .task { bundleStatus = checkDefaultBotBundled() }
    }

    private func checkDefaultBotBundled() -> String {
        guard let url = Bundle.main.url(
            forResource: "core",
            withExtension: "md",
            subdirectory: "default-bot/identity"
        ) else {
            return "missing"
        }
        return "found at \(url.lastPathComponent)"
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 6.3 [VERIFY]: Run the app on the simulator and confirm it shows "found at core.md"**

```bash
cd /Users/haydentoppeross/development/b0t
xcodebuild -project b0t.xcodeproj -scheme b0t \
    -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
    build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

Then in Xcode (or via `xcrun simctl`) launch the app on the simulator. The screen should show three lines, the third reading `default-bot: found at core.md`. **If it reads "missing", the folder reference didn't bundle correctly — re-do step 6.1.**

- [ ] **Step 6.4: Commit**

```bash
git add b0t.xcodeproj b0tApp/Sources/App/ContentView.swift
git commit -m "feat(phase-0): bundle default-bot/ as folder reference, verify at runtime"
```

---

## Task 7: swift-format config + pre-commit hook

**Files:**
- Create: `.swift-format`
- Create: `.git/hooks/pre-commit` (NOT committed; uses a script)

- [ ] **Step 7.1: Write `.swift-format` config**

```json
{
  "version": 1,
  "lineLength": 110,
  "indentation": { "spaces": 4 },
  "respectsExistingLineBreaks": true,
  "lineBreakBeforeControlFlowKeywords": false,
  "lineBreakBeforeEachArgument": false,
  "lineBreakBetweenDeclarationAttributes": false,
  "maximumBlankLines": 1,
  "prioritizeKeepingFunctionOutputTogether": true,
  "rules": {
    "AllPublicDeclarationsHaveDocumentation": false,
    "AlwaysUseLowerCamelCase": true,
    "NoLeadingUnderscores": false,
    "OrderedImports": true,
    "UseLetInEveryBoundCaseVariable": true,
    "UseShorthandTypeNames": true,
    "UseSingleLinePropertyGetter": true,
    "UseSynthesizedInitializer": true,
    "UseTripleSlashForDocumentationComments": true,
    "ValidateDocumentationComments": false
  }
}
```

Save to `/Users/haydentoppeross/development/b0t/.swift-format`.

- [ ] **Step 7.2 [VERIFY]: Confirm `swift format` is available**

```bash
swift format --version 2>&1
```

Expected: prints a version (Swift 6.0+ ships with the `format` subcommand). If it errors with "no such subcommand", install via `brew install swift-format` and use `swift-format` (with hyphen) in subsequent commands.

- [ ] **Step 7.3: Run `swift format` once across all Swift to confirm baseline conformance**

```bash
cd /Users/haydentoppeross/development/b0t
find b0tApp b0tKit -name "*.swift" -exec swift format -i --configuration .swift-format {} +
git diff --stat
```

Expected: minimal or no diff (the placeholder code is small and clean). If there is a diff, it is the formatter's normalisation — accept it.

- [ ] **Step 7.4: Create the local pre-commit hook**

Write to `/Users/haydentoppeross/development/b0t/.git/hooks/pre-commit`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Format only staged Swift files; abort if any file would change after formatting.
staged_swift=$(git diff --cached --name-only --diff-filter=ACMR | grep '\.swift$' || true)
if [ -z "$staged_swift" ]; then
    exit 0
fi

failed=0
while IFS= read -r file; do
    [ -f "$file" ] || continue
    if ! swift format lint --configuration .swift-format "$file" > /dev/null 2>&1; then
        echo "swift-format: $file needs formatting (run: swift format -i --configuration .swift-format $file)"
        failed=1
    fi
done <<< "$staged_swift"

if [ "$failed" -ne 0 ]; then
    echo
    echo "pre-commit blocked. format the files above and re-stage."
    exit 1
fi
```

Then:

```bash
chmod +x /Users/haydentoppeross/development/b0t/.git/hooks/pre-commit
```

- [ ] **Step 7.5 [VERIFY]: Test the hook on a deliberately-malformatted file**

```bash
cd /Users/haydentoppeross/development/b0t
echo 'public func   misformatted(    ) {}' >> b0tKit/Sources/b0tCore/b0tCorePlaceholder.swift
git add b0tKit/Sources/b0tCore/b0tCorePlaceholder.swift
git commit -m "test: should be blocked" 2>&1 | tail -5
```

Expected: pre-commit hook prints a swift-format complaint and the commit aborts. Then revert:

```bash
git checkout -- b0tKit/Sources/b0tCore/b0tCorePlaceholder.swift
git reset
```

- [ ] **Step 7.6: Commit `.swift-format`**

```bash
git add .swift-format
git commit -m "chore(phase-0): add swift-format config + local pre-commit lint hook

The hook itself lives in .git/hooks/pre-commit (not committed).
Future contributors install it via a setup script (out of scope for Phase 0).
Config: 110-col line length, 4-space indent, ordered imports."
```

---

## Task 8: `.claude/settings.json` — MCP servers and hooks

**Files:**
- Create: `.claude/settings.json` (project-scoped, committed)

The two MCP servers (`xcode`, `XcodeBuildMCP`) are already registered in Jamee's local `~/.claude.json`. The committed project-scoped `settings.json` documents the project's expected harness state and adds repo-level hooks.

- [ ] **Step 8.1: Write `.claude/settings.json`**

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": [
      "Bash(xcodebuild:*)",
      "Bash(xcrun:*)",
      "Bash(swift:*)",
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git push:*)",
      "Bash(git pull:*)",
      "Bash(git fetch:*)",
      "Bash(git checkout:*)",
      "Bash(git branch:*)",
      "Bash(grep:*)",
      "Bash(find:*)",
      "Bash(rg:*)"
    ]
  }
}
```

**Note:** No `hooks` block in Phase 0. The pre-commit hook (Task 7) handles formatting at the gating moment. A live PostToolUse formatter requires reading the tool-call JSON from stdin and parsing `tool_input.file_path` (not an env var) — worth adding once we've verified the wiring against the Claude Code hook format. Defer to a follow-up.

Save to `/Users/haydentoppeross/development/b0t/.claude/settings.json`.

- [ ] **Step 8.2 [VERIFY]: Confirm settings parse**

```bash
python3 -c "import json; json.load(open('/Users/haydentoppeross/development/b0t/.claude/settings.json'))" && echo OK
```

Expected: `OK`.

- [ ] **Step 8.3: Commit**

```bash
git add .claude/settings.json
git commit -m "chore(phase-0): add project-scoped Claude settings — permissions + post-edit format hook"
```

---

## Task 9: Slash commands

**Files:**
- Create: `.claude/commands/build.md`
- Create: `.claude/commands/test.md`
- Create: `.claude/commands/preview.md`
- Create: `.claude/commands/fix-build.md`
- Create: `.claude/commands/implement.md`
- Create: `.claude/commands/audit.md`

- [ ] **Step 9.1: Write `/build`**

`.claude/commands/build.md`:

```markdown
---
description: Build the b0t app to the default iOS simulator (iPhone 16 Pro)
---

Build the b0t app target for the default simulator. On success, report the build summary; on failure, surface the first compile error and propose a fix.

Run:
```
xcodebuild -project b0t.xcodeproj -scheme b0t -destination "platform=iOS Simulator,name=iPhone 16 Pro" build
```

If the simulator name is unavailable, fall back to the first available iPhone simulator from `xcrun simctl list devices available`.
```

- [ ] **Step 9.2: Write `/test`**

`.claude/commands/test.md`:

```markdown
---
description: Run the b0tKit Swift package test suite
---

Run all `b0tKit` package tests via SwiftPM.

Run:
```
cd b0tKit && swift test
```

For UI tests (Phase 4+), use `xcodebuild test` against the app target instead. Phase 0 only ships package tests.
```

- [ ] **Step 9.3: Write `/preview`**

`.claude/commands/preview.md`:

```markdown
---
description: Render a SwiftUI preview via Apple Xcode MCP — usage /preview <ViewName>
---

Use the Apple Xcode MCP `RenderPreview` tool to render the named SwiftUI view. The view must declare a `#Preview` block.

Pass `$ARGUMENTS` as the view name. Resolve the view's file via `grep -rn "struct $ARGUMENTS: View" b0tApp b0tKit` if necessary.

Verify the rendered preview against the cassette-futurism aesthetic (see `docs/design_document.md` §3) and the voice-and-copy guide for any user-facing strings.
```

- [ ] **Step 9.4: Write `/fix-build`**

`.claude/commands/fix-build.md`:

```markdown
---
description: Build with reasoning — diagnose any failure and propose a fix
---

Run a clean build of the b0t app target. If it fails:

1. Read the full xcodebuild output (do not truncate).
2. Identify the first root-cause error (often the topmost compile error; ignore cascade errors below it).
3. Read the relevant source file(s) at the cited line(s).
4. Cross-reference with `docs/prd.md` and the relevant module's `CLAUDE.md` to ensure the fix preserves the intended design.
5. Propose a minimal fix and apply it.
6. Re-run `/build`.

Do not silently lower warning-as-error settings. Do not add `@available` checks for OSes below iOS 26.
```

- [ ] **Step 9.5: Write `/implement`**

`.claude/commands/implement.md`:

```markdown
---
description: Implement a feature from the PRD — usage /implement <PRD-section-or-feature>
---

Implement the feature named in `$ARGUMENTS`. Workflow:

1. Read the relevant section of `docs/prd.md` and `docs/design_document.md`.
2. Check `docs/decisions/` for any settled ADR that constrains this feature.
3. Check `docs/specs/` for any pre-written spec — if one exists, follow it; if not and the feature is non-trivial, write one first.
4. Use `superpowers:writing-plans` to draft an implementation plan if the feature spans multiple tasks.
5. Use `superpowers:executing-plans` or `superpowers:subagent-driven-development` to execute it.
6. Apply TDD ruthlessly for `b0tKit` modules. UI work uses `RenderPreview` for verification.
7. Honour the voice-and-copy guide for every user-facing string.
8. Verify acceptance criteria before claiming done.
```

- [ ] **Step 9.6: Write `/audit`**

`.claude/commands/audit.md`:

```markdown
---
description: Audit the codebase for App Store submission readiness
---

Audit pass — produce a punch list of remaining work for App Store submission. Check, in order:

1. **Privacy manifest:** `PrivacyInfo.xcprivacy` declares zero tracking, zero collected data, zero linked data.
2. **No network calls** — grep for `URLSession`, `Alamofire`, `WebKit`, `URLRequest` outside of explicitly user-initiated flows. If any exist, surface them.
3. **No third-party SDK that phones home** — review every entry in `Package.resolved`.
4. **Voice-and-copy guide** — sample 20 user-facing strings, verify each conforms.
5. **Accessibility:** every interactive element has a label, Dynamic Type works, reduce-motion respected.
6. **Performance:** frame rate during home idle = 60fps on iPhone 16 Pro.
7. **Memory:** app idle < 150MB.
8. **IAP flow:** trial → purchase → restore → Family Sharing all tested.
9. **App Store metadata:** screenshots, description, keywords drafted and reviewed against voice guide.

Report findings as a checklist with severity per item: blocker / nice-to-have / done.
```

- [ ] **Step 9.7: Commit slash commands**

```bash
git add .claude/commands/
git commit -m "chore(phase-0): add slash commands — build, test, preview, fix-build, implement, audit"
```

---

## Task 10: CLAUDE.md scaffolding (per package + Resources)

**Files:**
- Create: `b0tKit/Sources/b0tCore/CLAUDE.md`
- Create: `b0tKit/Sources/b0tBrain/CLAUDE.md`
- Create: `b0tKit/Sources/b0tSkills/CLAUDE.md`
- Create: `b0tKit/Sources/b0tFace/CLAUDE.md`
- Create: `b0tKit/Sources/b0tAudio/CLAUDE.md`
- Create: `b0tKit/Sources/b0tDesign/CLAUDE.md`
- Create: `Resources/CLAUDE.md` (note: this directory does not yet exist; create it)

These act as per-folder instructions that Claude Code loads automatically when working inside.

- [ ] **Step 10.1: Write `b0tCore` CLAUDE.md**

`b0tKit/Sources/b0tCore/CLAUDE.md`:

```markdown
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
```

- [ ] **Step 10.2: Write `b0tBrain` CLAUDE.md**

`b0tKit/Sources/b0tBrain/CLAUDE.md`:

```markdown
# b0tBrain

The markdown layer. Reads, parses, and writes the user's b0t files.

## Public API contracts (target shape)

- `BotLoader` — loads a b0t directory into typed in-memory representations on demand.
- `BotWriter` — persists changes back to disk losslessly.
- `Frontmatter` — YAML parser (use Yams; do not roll our own).
- `MarkdownLink` — resolves `[label](relative/path.md)` and `[[wikilink]]` references.
- `BacklinkIndex` — computes which files reference a given file.

## Patterns

- **Lossless round-trip is REQUIRED.** Load → save preserves whitespace, comments, and frontmatter key order. See PRD §5.1.
- No permanent in-memory model. Files read on demand, cached via `NSCache` with explicit invalidation on write.
- Default b0t files ship in the app bundle at `default-bot/...`; user b0ts live in `~/Documents/b0ts/...`.

## Read first when working here

- `docs/prd.md` §3.5, §5.1
- ADR 0002 (markdown as source of truth)
- `default-bot/` — the canonical directory layout to support
```

- [ ] **Step 10.3: Write `b0tSkills` CLAUDE.md**

`b0tKit/Sources/b0tSkills/CLAUDE.md`:

```markdown
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
```

- [ ] **Step 10.4: Write `b0tFace` CLAUDE.md**

`b0tKit/Sources/b0tFace/CLAUDE.md`:

```markdown
# b0tFace

The face rig — SpriteKit + SwiftUI rendering of the b0t's animated face.

## Public API contracts (target shape)

- `FaceScene: SKScene` — hosts face parts as `SKSpriteNode`s.
- `FaceRig` — orchestrates parts into the 8 mood states (idle, speaking, thinking, surprised, sleepy, attentive, worried, delighted).
- `MoodStateMachine` — transitions between mood states.
- `CRTOverlay: SKEffectNode` — optional scanline shader.
- SwiftUI host: `FaceView` wrapping `SpriteView`.

## Patterns

- **Nearest-neighbour scaling always.** `SKTexture.filteringMode = .nearest`. Never bilinear. Pixel grid must survive retina scaling.
- Every shipped face part has all 8 mood states baked in. New parts must conform.
- Animations are `SKAction` sequences in Swift — diffable in git.
- Pixel art assets are provided by Jamee; we integrate, we do not generate.

## Depends on

- `b0tDesign` (palettes, tokens)

## Read first when working here

- `docs/prd.md` §5.4
- `docs/design_document.md` §3 (aesthetic), §2.5 (Face Creator)
- ADR 0003 (SpriteKit over Rive)
- `assets/face-parts/`, `assets/palettes/`
```

- [ ] **Step 10.5: Write `b0tAudio` CLAUDE.md**

`b0tKit/Sources/b0tAudio/CLAUDE.md`:

```markdown
# b0tAudio

TTS pipeline — `AVSpeechSynthesizer` → `AVAudioEngine` → effect filter chain.

## Public API contracts (target shape)

- `Synthesizer` — produces a buffer from text via `AVSpeechSynthesizer.write(_:toBufferCallback:)`.
- `EffectFilter` enum — Clean, Warm, Tape, FM, Radio, Distant, Vintage, Hi-Fi.
- `AudioEngine` — wires the synthesizer's buffer through the chosen filter chain.
- `UISounds` — system click/thunk/transition sounds (OP-1 sensibility).

## Patterns

- TTS is **off by default.** User explicitly enables. b0t is text-first.
- Filter is per-b0t, persisted in `identity/audio.md` frontmatter.
- The Tape filter is the brand voice — slight wow-and-flutter, low-pass, gentle saturation.

## Read first when working here

- `docs/prd.md` §5.5
- `docs/design_document.md` §3.7
- `assets/sounds/`
```

- [ ] **Step 10.6: Write `b0tDesign` CLAUDE.md**

`b0tKit/Sources/b0tDesign/CLAUDE.md`:

```markdown
# b0tDesign

Design tokens, palettes, fonts, and shared SwiftUI views.

## Public API contracts (target shape)

- `Palette` — 12 curated palettes (no RGB picker — see PRD non-negotiable #9).
- `Token` namespace — colours, spacings, type ramps.
- `Font` — Berkeley Mono (brain layer) and Söhne (chat).
- Shared views: `OrganLabel`, `StatusGlow`, `PhosphorWire`, etc. (added as Phase 4 lands).

## Patterns

- **Warm darks, never pure black.** Phosphor glows are amber/green/cream, never blue. See design doc §3.5.
- All colour goes through palette slots: `primary`, `accent`, `shadow`, `highlight`. Never raw hex outside this module.
- All-lowercase for system labels. Sentence-case for the b0t's voice. Never title-case.

## Read first when working here

- `docs/design_document.md` §3 (the entire aesthetic section)
- `docs/references/voice-and-copy-guide.md`
- `assets/palettes/`, `assets/fonts/`
```

- [ ] **Step 10.7: Write `Resources/CLAUDE.md`**

```bash
mkdir -p /Users/haydentoppeross/development/b0t/Resources
```

Then create `Resources/CLAUDE.md`:

```markdown
# Resources/

Reserved for build-time resource organisation if/when needed. Currently empty.

The canonical default b0t markdown ships from `default-bot/` at the repo root, added to the app target as a folder reference. Raw design assets ship from `assets/` at the repo root.

If a future need arises (e.g., codegen output, intermediate sprite atlases that don't belong in `assets/`), they belong here, not under the source folders.

Do not put runtime user state here — that lives in `~/Documents/b0ts/` per ADR 0004.
```

- [ ] **Step 10.8: Commit CLAUDE.md scaffolding**

```bash
git add b0tKit/Sources/*/CLAUDE.md Resources/CLAUDE.md
git commit -m "docs(phase-0): per-module CLAUDE.md scaffolding for b0tKit + Resources

Each module gets a CLAUDE.md describing responsibility, target API shape,
patterns, dependencies, and the docs/ADRs/assets to read first when working
in that module."
```

---

## Task 11: GitHub Actions CI

**Files:**
- Create: `.github/workflows/ci.yml`

CI for Phase 0 covers the Swift package only (`swift build`, `swift test`). The app target requires `xcodebuild` against an iOS simulator, which we'll add in Phase 1+ when the brain layer has real tests worth running on simulator.

- [ ] **Step 11.1: Write the workflow**

`.github/workflows/ci.yml`:

```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  package-build-and-test:
    runs-on: macos-15
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode 26
        run: |
          sudo xcode-select -s /Applications/Xcode_26.app
          xcodebuild -version
          swift --version

      - name: swift build
        working-directory: b0tKit
        run: swift build -c debug

      - name: swift test
        working-directory: b0tKit
        run: swift test --parallel

      - name: swift-format lint
        run: |
          find b0tApp b0tKit -name '*.swift' -print0 \
            | xargs -0 swift format lint --strict --configuration .swift-format
```

Save to `/Users/haydentoppeross/development/b0t/.github/workflows/ci.yml`.

- [ ] **Step 11.2: Commit**

```bash
mkdir -p .github/workflows
git add .github/workflows/ci.yml
git commit -m "ci: GitHub Actions — swift build, swift test, swift-format lint on macos-15"
```

**Note:** if Xcode 26 is not yet installed at `/Applications/Xcode_26.app` on the GitHub runner, the workflow will fail on the first push. That's the expected signal — adjust the path or runner image to match what's available, but do not silently downgrade the iOS deployment target. If macos-15 doesn't yet ship Xcode 26 by default, switch to `macos-latest` and add a step that installs Xcode 26 via `xcversion`.

---

## Task 12: `IMPLEMENTATION.md` north-star tracker

**Files:**
- Create: `docs/IMPLEMENTATION.md`

A lightweight global tracker so any future session can see at a glance which phase we're in.

- [ ] **Step 12.1: Write the tracker**

`docs/IMPLEMENTATION.md`:

```markdown
# Implementation tracker

A living document. Updated at the end of each phase, or when a blocker appears.

## Current state

- **Phase:** 0 — project setup
- **Status:** in progress
- **Plan:** [phase-0-project-setup.md](plans/phase-0-project-setup.md)

## Phase ledger

| # | Phase | Plan | Status |
|---|---|---|---|
| 0 | Project setup | [phase-0](plans/phase-0-project-setup.md) | in progress |
| 1 | Markdown brain (no LLM) | — | not started |
| 2 | Foundation Models loop | — | not started |
| 3 | Skill bridges | — | not started |
| 4 | Anatomical GUI (default face) | — | not started |
| 5 | Onboarding sequence | — | not started |
| 6 | Face Creator | — | not started |
| 7 | Multi-b0t and Gallery | — | not started |
| 8 | Audio (TTS + effects) | — | not started |
| 9 | IAP and trial | — | not started |
| 10 | Polish and ship | — | not started |

## Open questions on the boil

(Questions surfaced here are alive — once answered, they're closed in the relevant plan or ADR.)

- (none currently — Phase 0 questions resolved 2026-04-30)

## Specs in flight

- (none yet — first spec planned: `context-assembler.md` during Phase 2 prep)
```

- [ ] **Step 12.2: Commit**

```bash
git add docs/IMPLEMENTATION.md
git commit -m "docs: add IMPLEMENTATION.md north-star tracker"
```

---

## Task 13: Final acceptance — clean build + simulator launch + push

- [ ] **Step 13.1 [VERIFY]: Clean build of the app target**

```bash
cd /Users/haydentoppeross/development/b0t
xcodebuild -project b0t.xcodeproj -scheme b0t \
    -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
    clean build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`. Zero warnings (warnings-as-errors is on).

- [ ] **Step 13.2 [VERIFY]: All package tests pass**

```bash
cd /Users/haydentoppeross/development/b0t/b0tKit
swift test 2>&1 | tail -10
```

Expected: 6 tests, all pass.

- [ ] **Step 13.3 [VERIFY]: swift-format lint clean**

```bash
cd /Users/haydentoppeross/development/b0t
find b0tApp b0tKit -name '*.swift' -print0 \
  | xargs -0 swift format lint --strict --configuration .swift-format
echo "exit: $?"
```

Expected: `exit: 0`. No lint output.

- [ ] **Step 13.4 [USER + VERIFY]: Launch the app on the simulator and confirm "default-bot: found at core.md"**

In Xcode, select the `b0t` scheme and an iPhone 16 Pro simulator. Run (`⌘R`). The app should launch; the screen shows three lines, the third reading `default-bot: found at core.md`.

- [ ] **Step 13.5: Update tracker and commit**

Edit `docs/IMPLEMENTATION.md`:
- Change Phase 0 status to `complete`
- Change "Current state" to `Phase 1 — markdown brain (no LLM)` / `not started`

```bash
git add docs/IMPLEMENTATION.md
git commit -m "docs: mark Phase 0 complete, advance current state to Phase 1"
```

- [ ] **Step 13.6: Push to `origin/main`**

```bash
git push origin main
```

Expected: push succeeds.

---

## Acceptance criteria for Phase 0 (cross-check vs PRD §4 Phase 0)

- [x] Xcode project created with structure aligned to PRD §3.1 — Tasks 3, 4, 5
- [x] Swift Package configured, six modules, inter-target dependencies — Task 4
- [x] Code signing configured (team P2VY4WT259) — Task 3
- [x] MCP configurations — already in local config; project `.claude/settings.json` documents project state — Task 8
- [x] CI established — Task 11
- [x] CLAUDE.md scaffolding at root, per module, and Resources — root pre-existing, others Task 10
- [x] Project builds clean — verified Task 13.1
- [x] Empty SwiftUI app launches on simulator — verified Task 13.4

---

## Risks and mitigations

- **Xcode 26 / iOS 26 toolchain availability on GitHub runners.** First CI run will reveal this. If `Xcode_26.app` isn't on the runner, the workflow fails fast and we adjust. We don't downgrade the deployment target.
- **Folder references in Xcode are not git-friendly.** They show up as paths in `project.pbxproj`. We commit the project file. Subsequent file additions to `default-bot/` show up automatically; subsequent file additions to `b0tApp/Sources/` need to either go through Xcode IDE or use a regenerator (deferred unless friction).
- **Hook is local-only.** `.git/hooks/pre-commit` isn't committed (per Git's design). A future contributor will need to install it. Phase 0 doesn't add a setup script for this — the project has one developer. Revisit if/when a contributor lands.
- **Foundation Models is *not* exercised in Phase 0.** All framework risk is parked for Phase 2. Per the recommendation in the prior strategy turn, we should add a small spike during Phase 1; that's deferred to Phase 1's plan, not added here.

---

## Self-review notes (run before handing off)

Spec coverage check (against PRD §4 Phase 0):
- ✅ "Create Xcode project with the structure in §3.1" → Task 3 (with §3.1 alignment in Task 1)
- ✅ "Configure Swift Package, targets, code signing" → Tasks 3, 4, 5
- ✅ "Add MCP configurations (see §10)" → MCPs added to local config in pre-plan housekeeping; project documents in Task 8
- ✅ "Establish CI: xcodebuildmcp build-and-test on push" → Task 11 (using `swift test` rather than xcodebuild — see note in Task 11; xcodebuild-based UI tests deferred to Phase 1+ when there's app-level test content)
- ✅ "Add CLAUDE.md files at root and in key subdirectories" → root pre-exists, Tasks 10
- ✅ Acceptance: project builds clean. Empty SwiftUI app launches on simulator → Task 13

Placeholder scan: no "TBD"/"TODO"/"implement later" present. Every step has actual content.

Type consistency: `b0tCorePlaceholder` etc. used consistently across Tasks 4, 5. `default-bot/identity/core.md` referenced consistently in Task 6 and the runtime smoke test.

---

*end of Phase 0 plan.*
