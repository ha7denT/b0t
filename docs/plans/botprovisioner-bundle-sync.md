# BotProvisioner Bundle-Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On every launch, copy any bundled `default-bot/` file that is **missing** from the user's active bot directory into it — so app updates that add files (new modules, assets) reach existing installs — without ever overwriting files the user may have edited.

**Architecture:** Add a private `syncMissingFiles(from:into:)` helper to `BotProvisioner` that walks the bundled `default-bot/` tree and copies only files absent from the target (creating intermediate directories). Call it on the two code paths in `ensureDefaultBotProvisioned` that return an *existing* bot directory. The fresh-install path (`copyItem` of the whole tree) is unchanged; sync is a no-op there.

**Tech Stack:** Swift, `FileManager` (`enumerator`, `copyItem`, `createDirectory`), XCTest. Host-only logic in `b0tBrain` — no UI, no device needed.

**Scope (settled in design):** **additive only** — copies missing files; does NOT update bundled files whose content changed if the user still holds an older copy (that needs edit-detection, out of scope). A deliberately-deleted shipped file *will* reappear on next launch (accepted trade-off: a resurrected default beats a missing module). `journal/`, user-written `memory/*`, and `_active` are never in the bundle, so they're untouched.

---

### Task 1: `syncMissingFiles` helper + sync the active-bot path

**Files:**
- Modify: `b0tKit/Sources/b0tBrain/BotProvisioner.swift`
- Test: `b0tKit/Tests/b0tBrainTests/BotProvisionerTests.swift`

- [ ] **Step 1: Write the failing tests** — append to `BotProvisionerTests.swift` (inside the class). They reuse the existing `documents` / `bundleStubRoot` fixtures from `setUpWithError`:

```swift
func test_existingInstall_gainsNewlyBundledFile() throws {
    let source = bundleStubRoot.appendingPathComponent("default-bot")
    // First provision creates b0t-01 (+ _active) from the stub bundle.
    _ = try BotProvisioner.ensureDefaultBotProvisioned(
        documentsURL: documents, defaultBotSourceURL: source)

    // Simulate an app update that adds a new bundled module in a NEW subdir.
    let newModule = source.appendingPathComponent("modules/weather.md")
    try FileManager.default.createDirectory(
        at: newModule.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "---\nmodule_id: weather\n---\n".write(
        to: newModule, atomically: true, encoding: .utf8)

    // Second provision (active bot exists) must sync the new file in.
    let active = try BotProvisioner.ensureDefaultBotProvisioned(
        documentsURL: documents, defaultBotSourceURL: source)
    XCTAssertTrue(
        FileManager.default.fileExists(
            atPath: active.appendingPathComponent("modules/weather.md").path),
        "newly-bundled module should be synced into the existing install")
}

func test_sync_doesNotOverwriteUserEditedFile() throws {
    let source = bundleStubRoot.appendingPathComponent("default-bot")
    let active = try BotProvisioner.ensureDefaultBotProvisioned(
        documentsURL: documents, defaultBotSourceURL: source)
    // User edits an existing file.
    let core = active.appendingPathComponent("identity/core.md")
    try "user-edited\n".write(to: core, atomically: true, encoding: .utf8)
    // Add a new bundled file too, so the sync pass definitely runs.
    let newFile = source.appendingPathComponent("modules/weather.md")
    try FileManager.default.createDirectory(
        at: newFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "x\n".write(to: newFile, atomically: true, encoding: .utf8)

    _ = try BotProvisioner.ensureDefaultBotProvisioned(
        documentsURL: documents, defaultBotSourceURL: source)

    XCTAssertEqual(try String(contentsOf: core, encoding: .utf8), "user-edited\n")
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter BotProvisionerTests`
Expected: `test_existingInstall_gainsNewlyBundledFile` FAILS (the file isn't synced — current code returns the active dir untouched). `test_sync_doesNotOverwriteUserEditedFile` may pass already (no overwrite happens today) — that's fine; it guards the invariant once sync lands.

- [ ] **Step 3: Add the helper** — in `BotProvisioner.swift`, add this private static method inside the `enum BotProvisioner` (e.g. just before `starterDefaultsFromCatalogue`):

```swift
/// Copies any bundled file missing from `botDir` into it, creating
/// intermediate directories. NEVER overwrites an existing file (preserves
/// user edits). Returns the number of files added. Hidden files are skipped.
///
/// Additive only: a bundled file whose content changed upstream is not
/// re-copied if the user already has any version of it. A file the user
/// deleted will reappear (accepted trade-off — see the bundle-sync plan).
@discardableResult
static func syncMissingFiles(from bundledRoot: URL, into botDir: URL) throws -> Int {
    let fm = FileManager.default
    guard
        let enumerator = fm.enumerator(
            at: bundledRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles])
    else { return 0 }

    let rootComponentCount = bundledRoot.pathComponents.count
    var added = 0
    for case let fileURL as URL in enumerator {
        let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else { continue }
        // Path of fileURL relative to bundledRoot, rebuilt under botDir.
        let relativeComponents = Array(fileURL.pathComponents.dropFirst(rootComponentCount))
        let target = relativeComponents.reduce(botDir) { $0.appendingPathComponent($1) }
        if !fm.fileExists(atPath: target.path) {
            try fm.createDirectory(
                at: target.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try fm.copyItem(at: fileURL, to: target)
            added += 1
        }
    }
    return added
}
```

- [ ] **Step 4: Call it on the active-bot path** — in `ensureDefaultBotProvisioned`, in Step 1, before `return candidate`, sync into it. Change:

```swift
            if fm.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue {
                return candidate
            }
```
to:
```swift
            if fm.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue {
                let added = try syncMissingFiles(from: defaultBotSourceURL, into: candidate)
                #if DEBUG
                    if added > 0 { print("[b0t] provisioner synced \(added) new bundled file(s)") }
                #endif
                return candidate
            }
```

- [ ] **Step 5: Run to verify pass**

Run: `swift test --package-path b0tKit --filter BotProvisionerTests`
Expected: all BotProvisionerTests PASS (the two new ones + the 3 existing).

- [ ] **Step 6: Commit**

```bash
git add b0tKit/Sources/b0tBrain/BotProvisioner.swift b0tKit/Tests/b0tBrainTests/BotProvisionerTests.swift
git commit -m "feat(brain): sync missing bundled files into the active bot on launch"
```

---

### Task 2: sync the `b0t-01`-exists-without-`_active` path + finalize

**Files:**
- Modify: `b0tKit/Sources/b0tBrain/BotProvisioner.swift`
- Test: `b0tKit/Tests/b0tBrainTests/BotProvisionerTests.swift`

- [ ] **Step 1: Write the failing test** — append to `BotProvisionerTests.swift`:

```swift
func test_b01ExistsWithoutActivePointer_stillSyncsNewFiles() throws {
    let source = bundleStubRoot.appendingPathComponent("default-bot")
    _ = try BotProvisioner.ensureDefaultBotProvisioned(
        documentsURL: documents, defaultBotSourceURL: source)
    // Remove _active so Step 1 falls through to the b0t-01 path.
    try FileManager.default.removeItem(
        at: documents.appendingPathComponent("b0ts/_active"))
    // Add a new bundled file.
    let newFile = source.appendingPathComponent("memory/core.md")
    try FileManager.default.createDirectory(
        at: newFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "facts\n".write(to: newFile, atomically: true, encoding: .utf8)

    let active = try BotProvisioner.ensureDefaultBotProvisioned(
        documentsURL: documents, defaultBotSourceURL: source)
    XCTAssertEqual(active.lastPathComponent, "b0t-01")
    XCTAssertTrue(
        FileManager.default.fileExists(
            atPath: active.appendingPathComponent("memory/core.md").path),
        "new file should sync even when only _active was missing")
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter BotProvisionerTests`
Expected: `test_b01ExistsWithoutActivePointer_stillSyncsNewFiles` FAILS — Step 2 currently skips the copy because `b0t-01` already exists (`if !fm.fileExists`), so the new file is never synced.

- [ ] **Step 3: Sync in Step 2** — in `ensureDefaultBotProvisioned`, change Step 2:

```swift
        let target = b0ts.appendingPathComponent("b0t-01", isDirectory: true)
        if !fm.fileExists(atPath: target.path) {
            try fm.copyItem(at: defaultBotSourceURL, to: target)
        }
```
to:
```swift
        let target = b0ts.appendingPathComponent("b0t-01", isDirectory: true)
        if fm.fileExists(atPath: target.path) {
            // b0t-01 exists but _active was missing/invalid — sync new files in.
            try syncMissingFiles(from: defaultBotSourceURL, into: target)
        } else {
            try fm.copyItem(at: defaultBotSourceURL, to: target)
        }
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --package-path b0tKit --filter BotProvisionerTests`
Expected: all BotProvisionerTests PASS.

- [ ] **Step 5: Update the type doc comment** — the header comment on `enum BotProvisioner` (lines 3-8) says subsequent calls are no-ops. Replace it to reflect the sync:

```swift
/// First-launch bootstrap, plus an additive bundle-sync on every launch.
///
/// On first run, copies the bundled `default-bot/` content into
/// `<documents>/b0ts/b0t-01/` and writes the `_active` pointer. On every
/// subsequent run it syncs *missing* bundled files into the active bot
/// (so app updates that add files reach existing installs) but never
/// overwrites files the user may have edited. See
/// `docs/plans/botprovisioner-bundle-sync.md`.
```

- [ ] **Step 6: Full verification** — run the whole package suite to confirm no regressions (BotProvisioner is exercised by integration tests elsewhere):

Run: `swift test --package-path b0tKit --no-parallel 2>&1 | tail -3`
Expected: full suite green (was 392 before this plan; now 395 with the 3 new tests).

- [ ] **Step 7: Commit**

```bash
git add b0tKit/Sources/b0tBrain/BotProvisioner.swift b0tKit/Tests/b0tBrainTests/BotProvisionerTests.swift
git commit -m "feat(brain): sync new bundled files when only the _active pointer is missing"
```

---

## Self-review

**Spec coverage** (against the approved design):
- Additive sync of missing bundled files on launch → Task 1 (helper + active-bot path) + Task 2 (b0t-01-without-active path). ✓
- Never overwrite user edits → `syncMissingFiles` copies only when `!fileExists`; guarded by `test_sync_doesNotOverwriteUserEditedFile` and the existing `test_secondCall_isIdempotent_doesNotOverwrite`. ✓
- New subdirectories created → `createDirectory(withIntermediateDirectories: true)`; covered by `test_existingInstall_gainsNewlyBundledFile` (adds `modules/` which didn't exist). ✓
- Fresh-install path unchanged → Step 2's `else` branch keeps the original `copyItem`; `test_freshDocumentsDirectory_provisionsB01` still asserts it. ✓
- Deleted-file resurrection / additive-only scope → documented in the helper doc comment and type comment; no code attempts content-update or deletion-tracking (YAGNI). ✓
- User-only dirs untouched → they're never in `bundledRoot`, so the enumerator never visits them. ✓

**Placeholder scan:** none — every step has full code and exact commands.

**Type consistency:** `syncMissingFiles(from:into:) -> Int` is defined in Task 1 Step 3 and called identically in Task 1 Step 4 and Task 2 Step 3. `defaultBotSourceURL`, `candidate`, `target`, `b0ts` all match the existing `ensureDefaultBotProvisioned` names. Test fixtures (`documents`, `bundleStubRoot`) match `setUpWithError`. ✓
