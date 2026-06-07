import Foundation
import SwiftUI
import b0tBrain
import b0tCore
import b0tDesign

/// Builds the read-only `.md` tab content for a catalogue model (notes + source).
enum ProcessorModelNotes {
    static func markdown(for entry: InferenceModelEntry) -> String {
        var lines: [String] = ["# \(entry.displayName)", "", entry.disclosure, ""]
        lines.append("- license: \(entry.license)")
        lines.append("- context window: \(entry.contextWindow) tokens")
        if let quant = entry.quant { lines.append("- quantisation: \(quant)") }
        if let size = entry.sizeBytes {
            let gb = Double(size) / 1_000_000_000
            lines.append("- download size: \(String(format: "%.1f", gb)) GB")
        }
        if let repo = entry.repo, let sha = entry.pinnedSHA {
            lines.append("- source: \(repo) @ \(sha)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - ProcessorInspectionView

public struct ProcessorInspectionView: View {
    @Bindable var state: AnatomyState
    @State private var tab: Tab = .controls
    @State private var selection: (engineLabel: String, modelId: String) = ("…", "")

    enum Tab: String, CaseIterable { case controls, directory, md = ".md" }

    public init(state: AnatomyState) { self.state = state }

    private var models: [InferenceModelEntry] { InferenceModelCatalogue.production }
    private var selectedIndex: Int {
        max(0, models.firstIndex { $0.id == selection.modelId } ?? 0)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            switch tab {
            case .controls: controls
            case .directory: directory
            case .md: notes
            }
        }
        .padding(12)
        .task {
            selection = await state.processorController?.currentSelection() ?? selection
            await state.downloadCoordinator?.refresh()
        }
        .tint(ProcessorPalette.yellow)
    }

    private var header: some View {
        HStack {
            Text("▦ processor").font(Typography.systemMono(size: 16))
            Spacer()
            ForEach(Tab.allCases, id: \.self) { t in
                Button(t.rawValue) { tab = t }
                    .font(Typography.systemMono(size: 12))
                    .foregroundStyle(t == tab ? ProcessorPalette.yellow : .secondary)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("model").frame(width: 64, alignment: .leading)
                Button("◀") { cycle(-1) }
                Text(models[selectedIndex].displayName).frame(minWidth: 120)
                Button("▶") { cycle(1) }
            }
            Text("engine  \(selection.engineLabel)")
                .font(Typography.systemMono(size: 12)).foregroundStyle(.secondary)
            TokenGaugeView(usage: state.latestUsage)
        }.font(Typography.systemMono(size: 14))
    }

    private var directory: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(InferenceModelCatalogue.production) { entry in
                DownloadRowView(entry: entry, coordinator: state.downloadCoordinator)
            }
            if let c = state.downloadCoordinator {
                Text(storageLine(c)).font(Typography.systemMono(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var notes: some View {
        ScrollView {
            Text(ProcessorModelNotes.markdown(for: models[selectedIndex]))
                .font(Typography.systemMono(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func storageLine(_ c: ModelDownloadCoordinator) -> String {
        let used = Double(c.totalBytes - c.freeBytes) / 1_000_000_000
        let total = Double(c.totalBytes) / 1_000_000_000
        return "── storage \(String(format: "%.1f", used)) / \(String(format: "%.0f", total)) GB ──"
    }

    private func cycle(_ delta: Int) {
        let next = (selectedIndex + delta + models.count) % models.count
        let id = models[next].id
        Task {
            let outcome = await state.processorController?.selectModel(id: id)
            selection = await state.processorController?.currentSelection() ?? selection
            if case .missing = outcome { tab = .directory }  // bounce (spec §2)
        }
    }
}

// MARK: - ProcessorPalette

enum ProcessorPalette {
    static let yellow = Color(red: 0xEA / 255.0, green: 0xFF / 255.0, blue: 0x3D / 255.0)
}

// MARK: - TokenGaugeView

struct TokenGaugeView: View {
    let usage: GenerationUsage?

    var body: some View {
        let u = usage
        VStack(alignment: .leading, spacing: 2) {
            bar(label: "in ", value: u?.tokensIn ?? 0, limit: u?.limit ?? 0)
            bar(label: "out", value: u?.tokensOut ?? 0, limit: u?.limit ?? 0)
            Text("\((u?.tokensIn ?? 0) + (u?.tokensOut ?? 0)) / \(u?.limit ?? 0) ctx")
                .font(Typography.systemMono(size: 11)).foregroundStyle(.secondary)
        }
    }

    private func bar(label: String, value: Int, limit: Int) -> some View {
        let frac = limit > 0 ? min(1.0, Double(value) / Double(limit)) : 0
        return HStack(spacing: 6) {
            Text(label).font(Typography.systemMono(size: 11))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.secondary.opacity(0.2))
                    Rectangle().fill(ProcessorPalette.yellow)
                        .frame(width: geo.size.width * frac)
                }
            }.frame(height: 8)
            Text("\(value)").font(Typography.systemMono(size: 11)).frame(
                width: 48, alignment: .trailing)
        }
    }
}

// MARK: - DownloadRowView

struct DownloadRowView: View {
    let entry: InferenceModelEntry
    let coordinator: ModelDownloadCoordinator?

    var body: some View {
        let st = coordinator?.state(for: entry.id) ?? .notDownloaded
        HStack(spacing: 8) {
            switch st {
            case .downloaded: Text("✓")
            case .downloading: Text("↓")
            case .failed: Text("✗").foregroundStyle(.secondary)
            default: Text("·").foregroundStyle(.secondary)
            }
            Text(entry.displayName).frame(maxWidth: .infinity, alignment: .leading)
            switch st {
            case .downloading(let p):
                ProgressView(value: p).frame(width: 80)
                Button("cancel") { Task { await coordinator?.cancel(modelId: entry.id) } }
            case .downloaded:
                if let s = entry.sizeBytes {
                    Text(String(format: "%.1f GB", Double(s) / 1_000_000_000))
                        .font(Typography.systemMono(size: 11)).foregroundStyle(.secondary)
                }
            case .failed(let message):
                VStack(alignment: .trailing, spacing: 2) {
                    Text(message)
                        .font(Typography.systemMono(size: 11))
                        .foregroundStyle(.secondary)
                    Button("retry") { Task { await coordinator?.start(modelId: entry.id) } }
                }
            default:
                if entry.engine == .foundationModels {
                    Text("(built-in)").font(.caption2).foregroundStyle(.secondary)
                } else {
                    Button("download") { Task { await coordinator?.start(modelId: entry.id) } }
                }
            }
        }.font(Typography.systemMono(size: 12))
    }
}

// MARK: - Preview

#Preview("Processor — Controls") {
    let bot = Bot.empty(at: FileManager.default.temporaryDirectory.appendingPathComponent("preview"))
    let state = AnatomyState(bot: bot, store: BotStore(), initialHeartBPM: 60)
    state.processorController = StubProcessorController(
        engineLabel: "foundation models",
        modelId: "foundation_models_default",
        downloaded: ["qwen3-1.7b"])
    state.latestUsage = GenerationUsage(
        tokensIn: 1510, tokensOut: 220, limit: 4096, modelId: "qwen3-1.7b", breakdown: [:])
    return ProcessorInspectionView(state: state)
}
