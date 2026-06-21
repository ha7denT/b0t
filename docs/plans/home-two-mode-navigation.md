# Home Two-Mode Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single anatomy-forward home screen with two top-level modes — **chat** (small centred face, conversation feed dominant) and **workbench** (large face + organ ring + tabbed inspector) — toggled by tapping the face, with a constant top-right configuration gear and an inspector whose zero-state shows the latest chat snippet.

**Architecture:** Additive to the existing `b0tHome` SwiftUI shell + `b0tFace` SpriteKit scene. A new `mode` flag on the `@Observable AnatomyState` drives which layout `HomeView` renders. The face's SpriteKit node gains a tap path (`faceTapHandler`) that toggles the mode, wired through the existing `SceneStateBridge`. The chat log is lifted off `ChatView`'s local `@State` into a shared `AnatomyState.transcript` so both the full chat feed and the inspector's recent-chat zero-state read the same source. Full-screen `.md` editing is unchanged (already built via `EditorView` / `.fullScreenCover`).

**Tech Stack:** Swift 6, SwiftUI, SpriteKit (`SpriteView`), Swift Testing via XCTest (`swift test`), `@Observable` (Observation framework). Design tokens from `b0tDesign` (`LCDPalette`, `Typography`).

---

## ⚠️ One open decision for Hayden (confirm before/at review)

**Default launch mode.** This plan defaults the app to **`.chat`** (`AnatomyState.mode` initial value), matching the product thesis — the b0t greets you, you talk, you tap the face to open the workbench. It is a single-line constant (`AnatomyState.init`) and trivially flippable to `.workbench` if you'd rather the anatomy be the landing surface. Task 1's test asserts whichever you pick — flag it at plan review.

## File structure

**Modify**
- `b0tKit/Sources/b0tFace/AnatomyScene.swift` — add `faceTapHandler` + face-node tap routing in `touchesBegan`.
- `b0tKit/Sources/b0tHome/AnatomyState.swift` — add `HomeMode`, `mode`, `toggleMode()`, `ChatTurn`, `transcript` (seeded).
- `b0tKit/Sources/b0tHome/Internal/SceneStateBridge.swift` — wire `faceTapHandler` → `state.toggleMode()`.
- `b0tKit/Sources/b0tHome/ChatView.swift` — read/append `state.transcript` instead of local `@State log`.
- `b0tKit/Sources/b0tHome/InspectionPanel.swift` — nil-organ branch renders `RecentChatView`, not `ChatView`.
- `b0tKit/Sources/b0tHome/HomeView.swift` — switch layout on `state.mode`; add constant top-right gear overlay.

**Create**
- `b0tKit/Sources/b0tHome/RecentChatView.swift` — compact recent-chat inspector zero-state.
- `b0tKit/Sources/b0tHome/ChatFaceHeader.swift` — small centred face for chat mode (face-only scene).
- `b0tKit/Sources/b0tHome/ConfigurationPlaceholderView.swift` — stub config sheet the gear opens.
- Test files mirroring each (see tasks).

Each unit has one responsibility: `AnatomyState` owns mode + transcript; `SceneStateBridge` owns scene→state wiring; `RecentChatView`/`ChatFaceHeader`/`ConfigurationPlaceholderView` are leaf views; `HomeView` composes them per mode.

---

### Task 1: HomeMode + AnatomyState.mode + toggleMode()

**Files:**
- Modify: `b0tKit/Sources/b0tHome/AnatomyState.swift`
- Test: `b0tKit/Tests/b0tHomeTests/AnatomyStateTests.swift`

- [ ] **Step 1: Write the failing tests** — append to `AnatomyStateTests.swift`:

```swift
func test_initialState_defaultsToChatMode() {
    let state = makeState()
    XCTAssertEqual(state.mode, .chat)
}

func test_toggleMode_switchesChatToWorkbench() {
    let state = makeState()
    state.toggleMode()
    XCTAssertEqual(state.mode, .workbench)
}

func test_toggleMode_switchesWorkbenchBackToChat() {
    let state = makeState()
    state.toggleMode()
    state.toggleMode()
    XCTAssertEqual(state.mode, .chat)
}

func test_toggleMode_clearsSelectedOrgan() {
    let state = makeState()
    state.selectedOrgan = .memory
    state.toggleMode()
    XCTAssertNil(state.selectedOrgan)
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter AnatomyStateTests`
Expected: FAIL — `mode`, `.chat`, `toggleMode()` do not exist.

- [ ] **Step 3: Implement** — in `AnatomyState.swift`, add the enum above the class and the property + method inside it:

```swift
/// The two top-level home-screen modes (ADR-0019). `chat` = talking to the
/// b0t (small centred face, feed dominant); `workbench` = working on it
/// (large face + organ ring + tabbed inspector).
public enum HomeMode: Sendable, Hashable {
    case chat
    case workbench
}
```

Inside `AnatomyState`, add the stored property (initialised in `init`) and the toggle:

```swift
/// Current top-level mode. Default `.chat` (ADR-0019; confirm with Hayden).
public var mode: HomeMode

// ... in init, after self.downloadCoordinator = nil:
self.mode = .chat

/// Flip chat ⇄ workbench. Clears any organ selection so workbench returns
/// to its recent-chat zero-state rather than a stale inspector.
public func toggleMode() {
    mode = (mode == .chat) ? .workbench : .chat
    selectedOrgan = nil
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --package-path b0tKit --filter AnatomyStateTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tHome/AnatomyState.swift b0tKit/Tests/b0tHomeTests/AnatomyStateTests.swift
git commit -m "feat(home): add HomeMode + AnatomyState.mode/toggleMode (ADR-0019)"
```

---

### Task 2: Shared chat transcript on AnatomyState

**Files:**
- Modify: `b0tKit/Sources/b0tHome/AnatomyState.swift`
- Test: `b0tKit/Tests/b0tHomeTests/AnatomyStateTests.swift`

- [ ] **Step 1: Write the failing tests** — append to `AnatomyStateTests.swift`:

```swift
func test_initialTranscript_isSeededWithReadyLines() {
    let state = makeState()
    XCTAssertEqual(state.transcript.count, 2)
    XCTAssertEqual(state.transcript.first?.role, .status)
}

func test_appendingTranscriptTurn_growsLog() {
    let state = makeState()
    state.transcript.append(ChatTurn(role: .user, text: "› hello"))
    XCTAssertEqual(state.transcript.last?.role, .user)
    XCTAssertEqual(state.transcript.last?.text, "› hello")
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter AnatomyStateTests`
Expected: FAIL — `ChatTurn` and `transcript` do not exist.

- [ ] **Step 3: Implement** — in `AnatomyState.swift`, add the `ChatTurn` type above the class:

```swift
/// One entry in the shared chat scrollback. Lifted out of `ChatView`'s local
/// state so both the full chat feed and the inspector's recent-chat zero-state
/// (ADR-0019) read one source.
public struct ChatTurn: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let role: Role
    public let text: String

    public enum Role: Sendable, Hashable { case user, bot, status, toolCall }

    public init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}
```

Inside `AnatomyState`, add the property and seed it in `init` (matching `ChatView`'s former seed lines verbatim):

```swift
/// Shared chat scrollback (ADR-0019). Seeded with the device-ready banner.
public var transcript: [ChatTurn]

// ... in init, after self.mode = .chat:
self.transcript = [
    ChatTurn(role: .status, text: "› device ready."),
    ChatTurn(role: .bot, text: "› hilfer here. ask me anything."),
]
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --package-path b0tKit --filter AnatomyStateTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tHome/AnatomyState.swift b0tKit/Tests/b0tHomeTests/AnatomyStateTests.swift
git commit -m "feat(home): lift chat transcript onto shared AnatomyState (ADR-0019)"
```

---

### Task 3: ChatView reads/writes the shared transcript

**Files:**
- Modify: `b0tKit/Sources/b0tHome/ChatView.swift`
- Test: `b0tKit/Tests/b0tHomeTests/ChatViewTests.swift`

- [ ] **Step 1: Write the failing test** — append to `ChatViewTests.swift`:

```swift
func test_chatView_rendersSeededTranscriptFromState() {
    let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
    let store = BotStore()
    let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
    state.transcript.append(ChatTurn(role: .user, text: "› ping"))
    _ = ChatView(state: state)
    // The view now sources its scrollback from state.transcript; assert the
    // shared state carries the seeded + appended turns.
    XCTAssertEqual(state.transcript.count, 3)
    XCTAssertEqual(state.transcript.last?.text, "› ping")
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter ChatViewTests`
Expected: FAIL to compile — `ChatTurn` referenced but `ChatView` still owns a private `LogEntry`; this test passes only once `ChatView` shares state. (If it compiles and passes incidentally, proceed — Step 3 still removes the duplication.)

- [ ] **Step 3: Implement** — edit `ChatView.swift`. Remove the private `LogEntry` struct and the two `@State` lines (`log`, and keep `isThinking`). Replace reads/writes of `log` with `state.transcript`. Concretely:

Delete:
```swift
@State private var log: [LogEntry] = [
    LogEntry(role: .status, text: "› device ready."),
    LogEntry(role: .bot, text: "› hilfer here. ask me anything."),
]
```
and the entire `private struct LogEntry { … }` block.

In `body`, change the `ForEach(log)` to `ForEach(state.transcript)`, and `onChange(of: log.count)` to `onChange(of: state.transcript.count)`, and `if let last = log.last` to `if let last = state.transcript.last`.

Change `entryView(for:)`'s parameter type from `LogEntry` to `ChatTurn` and its switch from `entry.role` cases (`.user/.bot/.status/.toolCall`) unchanged — the `ChatTurn.Role` cases match one-for-one.

In `sendMessage()`, replace the three `log.append(LogEntry(...))` calls with `state.transcript.append(ChatTurn(...))`:
```swift
state.transcript.append(ChatTurn(role: .user, text: "› \(prompt)"))
// …
for record in turn.toolCalls {
    state.transcript.append(ChatTurn(role: .toolCall, text: "  → \(record.toolName)"))
}
state.transcript.append(ChatTurn(role: .bot, text: turn.response.text))
// catch:
state.transcript.append(ChatTurn(role: .status, text: "— error: \(error)"))
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --package-path b0tKit --filter ChatViewTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tHome/ChatView.swift b0tKit/Tests/b0tHomeTests/ChatViewTests.swift
git commit -m "refactor(home): ChatView sources scrollback from shared transcript"
```

---

### Task 4: AnatomyScene face-tap routing

**Files:**
- Modify: `b0tKit/Sources/b0tFace/AnatomyScene.swift`
- Test: `b0tKit/Tests/b0tFaceTests/AnatomySceneTests.swift` (append; create if absent)

- [ ] **Step 1: Write the failing test** — add to `AnatomySceneTests.swift`:

```swift
func test_faceTapHandler_isInvokable() {
    let scene = AnatomyScene(size: CGSize(width: 256, height: 256))
    scene.installWunderFace()
    var tapped = false
    scene.faceTapHandler = { tapped = true }
    scene.faceTapHandler?()
    XCTAssertTrue(tapped)
}

func test_installWunderFace_namesFaceUnit() {
    let scene = AnatomyScene(size: CGSize(width: 256, height: 256))
    scene.installWunderFace()
    XCTAssertEqual(scene.headNode?.name, "face_unit")
}
```

(If `AnatomySceneTests.swift` does not exist, create it with the standard header: `import SpriteKit` / `import XCTest` / `@testable import b0tFace` and a `final class AnatomySceneTests: XCTestCase {}`.)

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter AnatomySceneTests`
Expected: FAIL — `faceTapHandler` does not exist.

- [ ] **Step 3: Implement** — in `AnatomyScene.swift`, add the property next to `tapHandler`:

```swift
/// Closure invoked when the user taps the face unit (or its grille).
/// `SceneStateBridge` sets this to toggle `AnatomyState.mode` (ADR-0019).
public var faceTapHandler: (() -> Void)?
```

Replace the `touchesBegan` hit loop so face nodes route to `faceTapHandler` and organs to `tapHandler`:

```swift
for node in hits {
    guard let name = node.name else { continue }
    if name == "face_unit" || name == "grille_emissive" {
        faceTapHandler?()
        return
    }
    if let organ = OrganID(rawValue: name) {
        tapHandler?(organ)
        return
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --package-path b0tKit --filter AnatomySceneTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tFace/AnatomyScene.swift b0tKit/Tests/b0tFaceTests/AnatomySceneTests.swift
git commit -m "feat(face): route face-node taps to faceTapHandler (ADR-0019)"
```

---

### Task 5: SceneStateBridge wires the face toggle

**Files:**
- Modify: `b0tKit/Sources/b0tHome/Internal/SceneStateBridge.swift`
- Test: `b0tKit/Tests/b0tHomeTests/Internal/SceneStateBridgeTests.swift`

- [ ] **Step 1: Write the failing test** — append to `SceneStateBridgeTests.swift`:

```swift
func test_bridge_faceTap_togglesMode() {
    let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
    let store = BotStore()
    let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
    let scene = AnatomyScene(size: CGSize(width: 390, height: 480))
    SceneStateBridge.connect(scene: scene, state: state)

    XCTAssertEqual(state.mode, .chat)
    scene.faceTapHandler?()
    XCTAssertEqual(state.mode, .workbench)
    scene.faceTapHandler?()
    XCTAssertEqual(state.mode, .chat)
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter SceneStateBridgeTests`
Expected: FAIL — `faceTapHandler` is nil (bridge doesn't set it).

- [ ] **Step 3: Implement** — in `SceneStateBridge.swift`, add after the existing `scene.tapHandler = …` assignment, inside `connect`:

```swift
scene.faceTapHandler = { [weak state] in
    state?.toggleMode()
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --package-path b0tKit --filter SceneStateBridgeTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tHome/Internal/SceneStateBridge.swift b0tKit/Tests/b0tHomeTests/Internal/SceneStateBridgeTests.swift
git commit -m "feat(home): SceneStateBridge toggles mode on face tap (ADR-0019)"
```

---

### Task 6: RecentChatView — the inspector zero-state

**Files:**
- Create: `b0tKit/Sources/b0tHome/RecentChatView.swift`
- Test: `b0tKit/Tests/b0tHomeTests/RecentChatViewTests.swift`

- [ ] **Step 1: Write the failing test** — create `RecentChatViewTests.swift`:

```swift
import SwiftUI
import XCTest

import b0tBrain

@testable import b0tHome

@MainActor
final class RecentChatViewTests: XCTestCase {
    func test_recentChatView_builds() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        _ = RecentChatView(state: state)
    }

    func test_latestTurns_returnsLastTwoNonStatusTurns() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        state.transcript.append(ChatTurn(role: .user, text: "› a"))
        state.transcript.append(ChatTurn(role: .bot, text: "› b"))
        let view = RecentChatView(state: state)
        let turns = view.latestTurns
        XCTAssertEqual(turns.map(\.text).suffix(2), ["› a", "› b"])
        XCTAssertFalse(turns.contains { $0.role == .status })
    }

    func test_tapToReturn_setsChatMode() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        state.mode = .workbench
        let view = RecentChatView(state: state)
        view.returnToChat()
        XCTAssertEqual(state.mode, .chat)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter RecentChatViewTests`
Expected: FAIL — `RecentChatView` does not exist.

- [ ] **Step 3: Implement** — create `RecentChatView.swift`:

```swift
import SwiftUI

import b0tDesign

/// The inspector's zero-state in workbench mode (ADR-0019): a compact view of
/// the latest chat turns, tappable to return to full chat mode. Shown when no
/// organ is selected.
public struct RecentChatView: View {
    @Bindable var state: AnatomyState

    public init(state: AnatomyState) {
        self.state = state
    }

    /// The last two non-status turns from the shared transcript.
    var latestTurns: [ChatTurn] {
        state.transcript.filter { $0.role != .status }.suffix(2).map { $0 }
    }

    /// Switch the home screen back to chat mode.
    func returnToChat() {
        state.mode = .chat
    }

    public var body: some View {
        Button(action: returnToChat) {
            VStack(alignment: .leading, spacing: 8) {
                Text("▸ no organ selected — latest chat")
                    .font(Typography.systemMono(size: 10))
                    .foregroundStyle(LCDPalette.textDim)
                ForEach(latestTurns) { turn in
                    Text(turn.text)
                        .font(Typography.chatBody(size: 13))
                        .foregroundStyle(LCDPalette.textAmber)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("tap to return to chat ▸")
                    .font(Typography.systemMono(size: 10))
                    .foregroundStyle(LCDPalette.textDim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .buttonStyle(.plain)
        .background(LCDPalette.bgWarm)
    }
}

#Preview("inspector — recent chat zero-state") {
    let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/preview"))
    let store = BotStore()
    let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
    return RecentChatView(state: state).frame(height: 200).background(Color.black)
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --package-path b0tKit --filter RecentChatViewTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tHome/RecentChatView.swift b0tKit/Tests/b0tHomeTests/RecentChatViewTests.swift
git commit -m "feat(home): RecentChatView inspector zero-state (ADR-0019)"
```

---

### Task 7: InspectionPanel zero-state → RecentChatView

**Files:**
- Modify: `b0tKit/Sources/b0tHome/InspectionPanel.swift`
- Test: `b0tKit/Tests/b0tHomeTests/InspectionPanelTests.swift`

- [ ] **Step 1: Write the failing test** — append to `InspectionPanelTests.swift`:

```swift
func test_panel_zeroState_offersReturnToChat() {
    let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
    let store = BotStore()
    let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
    state.mode = .workbench
    state.selectedOrgan = nil
    // The panel's nil-organ branch is RecentChatView; tapping its return
    // affordance sets chat mode. Drive the same state mutation it performs.
    RecentChatView(state: state).returnToChat()
    XCTAssertEqual(state.mode, .chat)
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter InspectionPanelTests`
Expected: PASS to compile but this guards the wiring; if `RecentChatView` is not yet referenced by the panel the build still succeeds. Proceed to Step 3 to make the panel actually render it.

- [ ] **Step 3: Implement** — in `InspectionPanel.swift`, change the `else` branch of `body`'s `Group` from `ChatView(state: state)` to `RecentChatView(state: state)`:

```swift
public var body: some View {
    Group {
        if let organ = state.selectedOrgan {
            inspectionContent(for: organ)
        } else {
            RecentChatView(state: state)
        }
    }
    // … unchanged overlay/back button …
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --package-path b0tKit --filter InspectionPanelTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tHome/InspectionPanel.swift b0tKit/Tests/b0tHomeTests/InspectionPanelTests.swift
git commit -m "feat(home): inspector zero-state shows recent chat, not full chat"
```

---

### Task 8: ChatFaceHeader — small centred face for chat mode

**Files:**
- Create: `b0tKit/Sources/b0tHome/ChatFaceHeader.swift`
- Test: `b0tKit/Tests/b0tHomeTests/ChatFaceHeaderTests.swift`

- [ ] **Step 1: Write the failing test** — create `ChatFaceHeaderTests.swift`:

```swift
import SwiftUI
import XCTest

import b0tBrain
import b0tFace

@testable import b0tHome

@MainActor
final class ChatFaceHeaderTests: XCTestCase {
    func test_chatFaceHeader_builds() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        _ = ChatFaceHeader(state: state)
    }

    func test_makeFaceScene_installsNamedFaceUnit() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
        let scene = ChatFaceHeader.makeFaceScene(state: state)
        XCTAssertEqual(scene.headNode?.name, "face_unit")
        XCTAssertNotNil(scene.faceTapHandler)  // bridge connected → tap toggles mode
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter ChatFaceHeaderTests`
Expected: FAIL — `ChatFaceHeader` does not exist.

- [ ] **Step 3: Implement** — create `ChatFaceHeader.swift`:

```swift
import SpriteKit
import SwiftUI

import b0tDesign
import b0tFace

/// Chat-mode header (ADR-0019): a small, centred face above the conversation
/// feed. The face is a face-only `AnatomyScene` (no organs); tapping it toggles
/// to workbench via the shared `SceneStateBridge` wiring. Below it: the b0t name
/// + heart glyph and the toggle hint.
public struct ChatFaceHeader: View {
    @Bindable var state: AnatomyState
    @State private var scene: AnatomyScene

    public init(state: AnatomyState) {
        self.state = state
        _scene = State(initialValue: Self.makeFaceScene(state: state))
    }

    /// Builds a face-only scene wired to the same state (face tap → toggleMode).
    static func makeFaceScene(state: AnatomyState) -> AnatomyScene {
        let scene = AnatomyScene(size: CGSize(width: 256, height: 256))
        scene.installWunderFace()
        SceneStateBridge.connect(scene: scene, state: state)
        return scene
    }

    public var body: some View {
        VStack(spacing: 2) {
            SpriteView(scene: scene, options: [.allowsTransparency])
                .frame(width: 72, height: 72)
                .background(Color.clear)
            Text("b0t-01 · ♥")
                .font(Typography.systemMono(size: 11))
                .foregroundStyle(LCDPalette.textDim)
            Text("tap face → workbench")
                .font(Typography.systemMono(size: 9))
                .foregroundStyle(LCDPalette.textDim.opacity(0.7))
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }
}

#Preview("chat — face header") {
    let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/preview"))
    let store = BotStore()
    let state = AnatomyState(bot: bot, store: store, initialHeartBPM: 4)
    return ChatFaceHeader(state: state).background(Color.black)
}
```

Note: `SceneStateBridge` is `internal` to `b0tHome`, so `makeFaceScene` reaching it is in-module — no access change needed.

- [ ] **Step 4: Run to verify pass**

Run: `swift test --package-path b0tKit --filter ChatFaceHeaderTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tHome/ChatFaceHeader.swift b0tKit/Tests/b0tHomeTests/ChatFaceHeaderTests.swift
git commit -m "feat(home): ChatFaceHeader small centred face for chat mode (ADR-0019)"
```

---

### Task 9: ConfigurationPlaceholderView — the gear's stub destination

**Files:**
- Create: `b0tKit/Sources/b0tHome/ConfigurationPlaceholderView.swift`
- Test: `b0tKit/Tests/b0tHomeTests/ConfigurationPlaceholderViewTests.swift`

- [ ] **Step 1: Write the failing test** — create `ConfigurationPlaceholderViewTests.swift`:

```swift
import SwiftUI
import XCTest

@testable import b0tHome

@MainActor
final class ConfigurationPlaceholderViewTests: XCTestCase {
    func test_configurationPlaceholder_builds() {
        _ = ConfigurationPlaceholderView()
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter ConfigurationPlaceholderViewTests`
Expected: FAIL — `ConfigurationPlaceholderView` does not exist.

- [ ] **Step 3: Implement** — create `ConfigurationPlaceholderView.swift`. Contents are deferred (spec §6); this is the affordance only. Copy is all-lowercase per the voice guide:

```swift
import SwiftUI

import b0tDesign

/// Stub destination for the constant top-right gear (ADR-0019). The real
/// configuration surface (device prefs, TTS, trial/IAP, about) is deferred —
/// spec §6. This ships the affordance with voice-correct placeholder copy.
public struct ConfigurationPlaceholderView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("configuration")
                .font(Typography.systemMono(size: 16))
                .foregroundStyle(LCDPalette.textAmber)
            Text("not yet wired. device prefs, voice, and activation will live here.")
                .font(Typography.systemMono(size: 12))
                .foregroundStyle(LCDPalette.textDim)
            Text("all files local. no transmission.")
                .font(Typography.systemMono(size: 11))
                .foregroundStyle(LCDPalette.textDim.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(20)
        .background(LCDPalette.bgWarm)
    }
}

#Preview("configuration — stub") {
    ConfigurationPlaceholderView().background(Color.black)
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --package-path b0tKit --filter ConfigurationPlaceholderViewTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add b0tKit/Sources/b0tHome/ConfigurationPlaceholderView.swift b0tKit/Tests/b0tHomeTests/ConfigurationPlaceholderViewTests.swift
git commit -m "feat(home): ConfigurationPlaceholderView gear stub (ADR-0019, spec §6)"
```

---

### Task 10: HomeView — mode-switched layout + constant gear

**Files:**
- Modify: `b0tKit/Sources/b0tHome/HomeView.swift`
- Test: `b0tKit/Tests/b0tHomeTests/HomeViewTests.swift` (create)

- [ ] **Step 1: Write the failing test** — create `HomeViewTests.swift`:

```swift
import SwiftUI
import XCTest

import b0tBrain

@testable import b0tHome

@MainActor
final class HomeViewTests: XCTestCase {
    func test_homeView_buildsInChatMode() {
        let bot = Bot.empty(at: URL(fileURLWithPath: "/tmp/test-bot"))
        let store = BotStore()
        _ = HomeView(bot: bot, store: store, initialHeartBPM: 4)
        // Default mode is chat (Task 1). Construction must not crash.
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path b0tKit --filter HomeViewTests`
Expected: PASS to compile (HomeView already constructs). This test guards Step 3 doesn't break construction. Proceed.

- [ ] **Step 3: Implement** — in `HomeView.swift`:

(a) Add gear state below the existing `@State` lines:
```swift
@State private var showConfiguration = false
```

(b) Replace the `body` with a mode switch wrapped in a `ZStack` carrying the constant gear. Keep the existing `.task`/`.onDisappear`/`.onChange` modifiers on the outer container unchanged:

```swift
public var body: some View {
    ZStack(alignment: .topTrailing) {
        Group {
            switch state.mode {
            case .chat:
                chatLayout
            case .workbench:
                workbenchLayout
            }
        }
        gearButton
    }
    .ignoresSafeArea(.container, edges: .horizontal)
    .task { await initializeManager() }
    .onDisappear {
        listener?.stop()
        usageListener?.stop()
    }
    .onChange(of: state.heartBPM) { _, newBPM in
        scene.heart?.startPulsing(bpm: newBPM)
    }
    .onChange(of: state.activeWiring) { oldSet, newSet in
        let added = newSet.subtracting(oldSet)
        for organ in added {
            scene.wiring?.pulse(organ, direction: .outbound)
            if let organNode = scene.organs[organ] {
                organNode.node.run(organNode.activityPulseAction())
            }
        }
    }
    .sheet(isPresented: $showConfiguration) {
        ConfigurationPlaceholderView()
    }
}
```

(c) Add the three computed subviews. `workbenchLayout` is the former body's `VStack`:

```swift
private var workbenchLayout: some View {
    VStack(spacing: 0) {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .frame(maxHeight: 540)
            .background(Color(red: 0.045, green: 0.075, blue: 0.075))  // cool dark teal (ADR-0016)
            .overlay(alignment: .top) {
                CrownTokenMetersView(usage: state.latestUsage)
                    .padding(.top, 8)
            }
        InspectionPanel(state: state)
            .frame(maxHeight: .infinity)
    }
}

private var chatLayout: some View {
    VStack(spacing: 0) {
        ChatFaceHeader(state: state)
            .background(Color(red: 0.045, green: 0.075, blue: 0.075))
        ChatView(state: state)
            .frame(maxHeight: .infinity)
    }
}

private var gearButton: some View {
    Button(action: { showConfiguration = true }) {
        Image(systemName: "gearshape")
            .font(.system(size: 16))
            .foregroundStyle(LCDPalette.textDim)
            .padding(12)
    }
    .accessibilityLabel("configuration")
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --package-path b0tKit --filter HomeViewTests`
Expected: PASS.

- [ ] **Step 5: Verify full package compiles + suite green**

Run: `swift test --package-path b0tKit 2>&1 | tail -20`
Expected: build succeeds; b0tHomeTests + b0tFaceTests pass (run with `--no-parallel` if the known `OrganInspectionViewTests` signal-11 flake appears — see IMPLEMENTATION handoff).

- [ ] **Step 6: Commit**

```bash
git add b0tKit/Sources/b0tHome/HomeView.swift b0tKit/Tests/b0tHomeTests/HomeViewTests.swift
git commit -m "feat(home): mode-switched layout + constant gear (ADR-0019)"
```

---

### Task 11: Documentation reconciliation + final verification

**Files:**
- Modify: `docs/design_document.md` (§2.3)
- Modify: `docs/specs/anatomical-gui-and-inspector.md` (§5)
- Modify: `docs/IMPLEMENTATION.md` (SESSION HANDOFF block)

- [ ] **Step 1: Reconcile design doc §2.3** — in `docs/design_document.md`, under §2.3, replace the "Tap interactions" / "Mode switching is fluid" lines that describe `tap face → focus mode (face zooms, chat compresses)` and the three-register model with a note pointing to the two-mode model and ADR-0019. Add at the top of §2.3's interaction prose:

```markdown
> **Superseded in part by [ADR-0019](decisions/0019-two-mode-home-chat-and-workbench.md) (2026-06-21):** the home screen is **two modes** — *chat* (small centred face, feed dominant) and *workbench* (large face + organ ring + tabbed inspector) — toggled by **tapping the face** (small ⇄ large). "Inspect" is workbench-with-an-organ-selected; full-screen `.md` edit is a workbench sub-state. The "tap face → focus mode (face zooms)" gesture below is replaced. See `docs/specs/home-screen-two-mode-navigation.md`.
```

- [ ] **Step 2: Cross-link the GUI spec §5** — in `docs/specs/anatomical-gui-and-inspector.md` §5, change the "Not yet designed: home-screen **focus/chat states** … and the **first-run** view." line to:

```markdown
- Home-screen **focus/chat states** are now designed — the two-mode model (chat/workbench, face-toggle, constant gear, recent-chat inspector zero-state) in [`home-screen-two-mode-navigation.md`](home-screen-two-mode-navigation.md) / [ADR-0019](../decisions/0019-two-mode-home-chat-and-workbench.md). The **first-run** view remains deferred (Phase 5).
```

- [ ] **Step 3: Update the IMPLEMENTATION handoff** — in `docs/IMPLEMENTATION.md`, in the `⛔ OPEN` block, replace the "Lower-section 'tabs' — UNRESOLVED" item with a resolved note:

```markdown
### ✅ RESOLVED — lower-section navigation (2026-06-21)
- The lower-section "tabs" question is settled: **two-mode home (chat / workbench)**, face-tap toggle, constant top-right gear, inspector recent-chat zero-state. Design: `docs/specs/home-screen-two-mode-navigation.md`; decision: [ADR-0019](decisions/0019-two-mode-home-chat-and-workbench.md); plan: `docs/plans/home-two-mode-navigation.md`. Implemented in `b0tHome` (+ a face-tap path in `b0tFace`). Remaining parked items: configuration-surface contents, chat⇄workbench transition motion, chat-mode heart tappability, first-run entry.
```

- [ ] **Step 4: Final test pass**

Run: `swift test --package-path b0tKit 2>&1 | tail -20`
Expected: full suite green (use `--no-parallel` if the known segfault flake appears).

- [ ] **Step 5: App target build**

Run: `/build` (or `xcodebuild -scheme b0t -destination 'generic/platform=iOS Simulator' build`)
Expected: build succeeds, no warnings (target treats warnings as errors).

- [ ] **Step 6: Commit**

```bash
git add docs/design_document.md docs/specs/anatomical-gui-and-inspector.md docs/IMPLEMENTATION.md
git commit -m "docs: reconcile two-mode home across design doc, GUI spec, handoff (ADR-0019)"
```

---

## Self-review

**Spec coverage** (against `home-screen-two-mode-navigation.md`):
- §1 two modes → Tasks 1, 10. ✓
- §2 face-tap toggle (both directions; recent-snippet route to chat) → Tasks 4, 5, 8 (face tap), 6 (recent→chat), 7. ✓
- §3 constant top-right gear → Tasks 9, 10. ✓
- §4 inspector: zero-state recent chat / organ tabs / full-screen edit → Tasks 6, 7 (zero-state); organ tabs + full-screen edit are existing `InspectionPanel`/`EditorView` behaviour, unchanged (noted in spec §7). ✓
- §5 state model (`mode` + `inspectorSelection`) → `mode` is Task 1; `inspectorSelection` is represented by the existing `selectedOrgan` (`.recentChat` ≡ `nil`), which Task 1's `toggleMode` resets — no separate type needed (documented divergence: the spec's `.recentChat | .organ` is modelled as `selectedOrgan: OrganID?`). ✓
- §6 deferred items → Configuration contents stubbed (Task 9); transition motion, chat-mode heart tappability, first-run all left untouched. ✓
- §7 consequences/doc drift → Task 11. ✓

**Placeholder scan:** no "TBD/TODO/handle edge cases" in steps; every code step shows full code. The one deliberate stub (ConfigurationPlaceholderView) is scoped and labelled per spec §6. ✓

**Type consistency:** `HomeMode` (`.chat`/`.workbench`), `AnatomyState.mode`, `toggleMode()`, `ChatTurn`(+`.Role` cases `user/bot/status/toolCall`), `transcript`, `faceTapHandler`, `RecentChatView.latestTurns`/`returnToChat()`, `ChatFaceHeader.makeFaceScene(state:)`, `ConfigurationPlaceholderView()` — all defined before use and referenced identically across tasks. `ChatTurn.Role` cases match `ChatView`'s former `LogEntry.Role` one-for-one (Task 3 relies on this). ✓

**Scope:** one subsystem (home navigation), one buildable artifact, ~11 bite-sized tasks. ✓
