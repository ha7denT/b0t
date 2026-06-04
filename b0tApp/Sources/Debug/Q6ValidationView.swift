#if DEBUG
    import SwiftUI
    import UniformTypeIdentifiers
    import b0tCore
    import b0tLlama

    /// On-device §14 Q6 model-lineup validation harness (DEBUG-only).
    ///
    /// Pick a GGUF (Files / AirDrop it onto the device first), tap Run, read the
    /// six checks from `docs/specs/phase-2c-q6-model-lineup-validation.md` §5 on
    /// screen. Repeat for each model in the trio. Measurements are programmatic
    /// (peak RAM, latency); checks 1–4 only produce real numbers on a device.
    struct Q6ValidationView: View {
        @State private var pickedModel: URL?
        @State private var isRunning = false
        @State private var progress = ""
        @State private var report: Q6CheckReport?
        @State private var showImporter = false

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    intro
                    Button {
                        showImporter = true
                    } label: {
                        Label(
                            pickedModel?.lastPathComponent ?? "pick a .gguf model",
                            systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await run() }
                    } label: {
                        Label("run 6 checks", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pickedModel == nil || isRunning)

                    if isRunning {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(progress).font(.system(.caption, design: .monospaced))
                        }
                    }
                    if let report { reportView(report) }
                }
                .padding()
            }
            .navigationTitle("Q6 validation")
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [UTType(filenameExtension: "gguf") ?? .data]
            ) { result in
                if case .success(let url) = result { pickedModel = url }
            }
        }

        private var intro: some View {
            Text(
                "Side-load each Q4_K_M GGUF (Qwen3-1.7B / Llama 3.2 1B / Qwen2.5-1.5B), "
                    + "run, and record the rows into the spec's §6 table. "
                    + "Check #3 is a first-token proxy (1-token generate); RAM is phys_footprint."
            )
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
        }

        @ViewBuilder
        private func reportView(_ r: Q6CheckReport) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(r.modelName).font(.headline)
                row("1 · template gate", r.templateGate)
                row("2 · peak RAM @4k", r.peakRAM4k)
                row("2 · peak RAM @8k", r.peakRAM8k)
                row("2 · avail after load", r.availableAfterLoad)
                row("3 · first-token (proxy)", r.firstTokenLatency)
                row("4 · throughput", r.throughput)
                row("5 · GBNF JSON ok", r.structuredOutput)
                row("6 · tool-call", r.toolCall)
                if let note = r.note {
                    Text(note).font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.orange)
                }
            }
            .font(.system(.callout, design: .monospaced))
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }

        private func row(_ label: String, _ value: String) -> some View {
            HStack(alignment: .top) {
                Text(label).frame(width: 170, alignment: .leading).foregroundStyle(.secondary)
                Text(value)
            }
        }

        private func run() async {
            guard let url = pickedModel else { return }
            isRunning = true
            report = nil
            defer { isRunning = false }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            report = await Q6Runner.run(modelURL: url) { msg in
                await MainActor.run { progress = msg }
            }
        }
    }
#endif
