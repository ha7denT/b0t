import SwiftUI

import b0tDesign

/// The Tools organ surfaces a virtual directory built from the live ToolRegistry.
/// Each tool gets a pseudo-file view (read-only metadata for v1).
public struct ToolsDirectoryView: View {
    @Bindable var state: AnatomyState

    public init(state: AnatomyState) { self.state = state }

    public var body: some View {
        // ToolRegistry surface is exposed by b0tCore / b0tModules. v1 lists
        // statically the 4 shipped Phase 3 tools. Phase 4.5+ wires this to
        // the live registry.
        List(
            [
                "calendar.upcoming_events",
                "reminders.create",
                "reminders.list",
                "health.steps_today",
            ], id: \.self
        ) { name in
            Text(name)
                .font(Typography.systemMono(size: 13))
                .foregroundStyle(LCDPalette.textAmber)
                .listRowBackground(LCDPalette.bgWarm)
        }
        .listStyle(.plain)
        .background(LCDPalette.bgWarm)
    }
}
