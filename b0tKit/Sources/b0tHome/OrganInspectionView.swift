import SwiftUI

import b0tBrain
import b0tDesign
import b0tFace

/// Inspection view for a single organ. Renders prose via MarkdownRenderer +
/// frontmatter as native controls inline (per spec §4.6).
///
/// On any control commit, the file is rewritten through BotStore. For heart:
/// commit also updates AnatomyState.heartBPM so the scene's HeartNode restarts.
public struct OrganInspectionView: View {
    @Bindable var state: AnatomyState
    let organ: OrganID
    let file: BotFile

    public init(state: AnatomyState, organ: OrganID, file: BotFile) {
        self.state = state
        self.organ = organ
        self.file = file
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(orderedFrontmatterKeys(), id: \.self) { key in
                    if let value = file.frontmatter[key],
                        let spec = FrontmatterControlDispatcher.control(
                            forKey: key, value: value,
                            onUpdate: { newValue in commit(key: key, value: newValue) })
                    {
                        controlView(for: spec)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 32)  // leave room for "back" affordance in InspectionPanel
            MarkdownRenderer(markdown: file.prose)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(LCDPalette.bgWarm)
    }

    @ViewBuilder
    private func controlView(for spec: FrontmatterControlSpec) -> some View {
        switch spec.kind {
        case .bpmSlider:
            if case .int(let v) = spec.value {
                BPMSlider(value: v, onCommit: spec.onUpdate)
            }
        case .quietHoursPicker:
            if case .array(let entries) = spec.value, entries.count == 2,
                case .string(let s) = entries[0], case .string(let e) = entries[1]
            {
                QuietHoursPicker(start: s, end: e, onCommit: spec.onUpdate)
            }
        case .enabledToggle:
            if case .bool(let b) = spec.value {
                EnabledToggle(
                    moduleName: file.fileURL.deletingPathExtension().lastPathComponent,
                    value: b, onCommit: spec.onUpdate)
            }
        case .toggle:
            if case .bool(let b) = spec.value {
                BoolToggleControl(label: spec.key, value: b, onCommit: spec.onUpdate)
            }
        case .stepper:
            if case .int(let i) = spec.value {
                StepperControl(label: spec.key, value: i, onCommit: spec.onUpdate)
            }
        case .textField:
            if case .string(let s) = spec.value {
                TextFieldControl(label: spec.key, value: s, onCommit: spec.onUpdate)
            }
        case .clockTimePicker, .clockRangePicker, .enumPicker:
            // Wired in Slice 6+ as the file shapes that need them surface.
            EmptyView()
        }
    }

    private func orderedFrontmatterKeys() -> [String] {
        // Stable ordering: known keys first (bpm, quiet_hours, enabled), then alphabetical
        // for the remainder. The known order matches the semantic registry's prominence.
        let known: [String] = ["heartbeat_bpm", "bpm", "quiet_hours", "enabled"]
        let frontmatterKeys = file.frontmatter.keys
        let knownPresent = known.filter { frontmatterKeys.contains($0) }
        let rest = frontmatterKeys.filter { !known.contains($0) }.sorted()
        return knownPresent + rest
    }

    func commit(key: String, value: YAMLValue) {
        let updated = file.settingFrontmatter(key, to: value)
        // Bridge to BotStore actor — fire-and-forget; failures will surface on next read.
        let store = state.store
        Task { try? await store.write(updated) }

        // Special case: heart BPM round-trips through AnatomyState so the scene picks it up.
        if (key == "heartbeat_bpm" || key == "bpm"),
            case .int(let bpm) = value
        {
            state.heartBPM = bpm
        }
    }
}
