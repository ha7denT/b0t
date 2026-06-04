#if DEBUG
    import Foundation
    import b0tCore
    import b0tLlama

    /// One model's six-check result, rendered by `Q6ValidationView`. Each field
    /// is a display string (a measurement, or an error/skip marker).
    struct Q6CheckReport: Sendable {
        var modelName: String
        var templateGate = "—"
        var peakRAM4k = "—"
        var peakRAM8k = "—"
        var availableAfterLoad = "—"
        var firstTokenLatency = "—"
        var throughput = "—"
        var structuredOutput = "—"
        var toolCall = "—"
        var note: String?
    }

    /// Device-bound runner for the Q6 protocol. Not unit-tested — the pure logic
    /// it leans on (grammar, parsing, scoring) is covered in `b0tLlamaTests`;
    /// here we drive a real model and measure. Errors are captured into the
    /// report rather than thrown, so one failed check doesn't abort the rest.
    enum Q6Runner {
        static func run(
            modelURL: URL,
            progress: @escaping @Sendable (String) async -> Void
        ) async -> Q6CheckReport {
            var report = Q6CheckReport(modelName: modelURL.lastPathComponent)

            // Load at 4k for checks 1,3,4,5,6 and RAM@4k.
            await progress("loading @4k…")
            let baseline = MemoryProbe.physFootprint()
            let runtime: LlamaRuntime
            do {
                runtime = try LlamaRuntime(modelPath: modelURL, contextLength: 4096)
            } catch {
                report.templateGate = "LOAD FAILED"
                report.note = "load @4k failed: \(error)"
                return report
            }
            let afterLoad = MemoryProbe.physFootprint()
            report.availableAfterLoad = MemoryProbe.mib(MemoryProbe.availableMemory())

            // #1 template gate.
            await progress("check 1: template gate…")
            do {
                let rendered = try await runtime.renderChatTemplate([
                    .init(role: "system", content: "S"), .init(role: "user", content: "U"),
                ])
                let head = rendered.prefix(40).replacingOccurrences(of: "\n", with: "⏎")
                report.templateGate = "PASS · \(head)"
            } catch {
                report.templateGate = "FAIL (templateApplyFailed) — DISQUALIFIED"
            }

            // #3 first-token latency (proxy: 1-token generate).
            await progress("check 3: first-token…")
            var peak = max(baseline, afterLoad)
            do {
                let t0 = Date()
                _ = try await runtime.generate(
                    messages: [.init(role: "user", content: "Hello.")], grammar: nil, maxTokens: 1)
                report.firstTokenLatency = String(
                    format: "%.0f ms", Date().timeIntervalSince(t0) * 1000)
            } catch {
                report.firstTokenLatency = "err: \(error)"
            }
            peak = max(peak, MemoryProbe.physFootprint())

            // #4 throughput (estimate: chars/4 per second over a 128-token run).
            await progress("check 4: throughput…")
            do {
                let t0 = Date()
                let out = try await runtime.generate(
                    messages: [.init(role: "user", content: "Count slowly from one to twenty.")],
                    grammar: nil, maxTokens: 128)
                let secs = Date().timeIntervalSince(t0)
                let estTokens = Double(out.count) / 4.0
                report.throughput = String(format: "~%.1f tok/s (est)", estTokens / max(secs, 0.001))
            } catch {
                report.throughput = "err: \(error)"
            }
            peak = max(peak, MemoryProbe.physFootprint())
            report.peakRAM4k = MemoryProbe.mib(peak)

            // #5 GBNF structured output over 5 trials.
            await progress("check 5: GBNF JSON…")
            let engine = LlamaEngine(runtimeReusing: runtime)
            var ok = 0
            let trials = 5
            for i in 0..<trials {
                await progress("check 5: GBNF JSON \(i + 1)/\(trials)…")
                let ctx = AssembledContext(
                    systemInstructions: "You are a terse assistant.",
                    userPrompt: "Greet the user in one short sentence.",
                    tools: [],
                    budget: .init(
                        estimated: 0, limit: 2048, breakdown: [:], didFallBackToDigest: false),
                    loadedFiles: [])
                if let _ = try? await engine.generate(
                    context: ctx, generating: ConversationResponse.self)
                {
                    ok += 1
                }
            }
            report.structuredOutput = "\(ok)/\(trials)"

            // #6 tool-call hit-rate over the fixed probe set.
            await progress("check 6: tool-call…")
            let loop = LlamaToolCallLoop(runtime: runtime)
            var results: [(probe: ToolCallProbe, call: ToolCallEnvelope?)] = []
            for (i, probe) in Q6ToolCallFixtures.probes.enumerated() {
                await progress("check 6: tool-call \(i + 1)/\(Q6ToolCallFixtures.probes.count)…")
                let call = try? await loop.pickTool(
                    userPrompt: probe.prompt, tools: Q6ToolCallFixtures.descriptors)
                results.append((probe, call))
            }
            let score = Q6ToolCallFixtures.score(results)
            report.toolCall = String(
                format: "hit %d/%d (%.0f%%) · parsed %d/%d",
                score.correctTool, score.total, score.hitRate * 100, score.parsed, score.total)

            // #2 RAM@8k — reload at 8k and sample.
            await progress("check 2: RAM @8k…")
            do {
                let r8 = try LlamaRuntime(modelPath: modelURL, contextLength: 8192)
                let afterLoad8 = MemoryProbe.physFootprint()
                _ = try await r8.generate(
                    messages: [.init(role: "user", content: "Hi.")], grammar: nil, maxTokens: 8)
                report.peakRAM8k = MemoryProbe.mib(max(afterLoad8, MemoryProbe.physFootprint()))
            } catch {
                report.peakRAM8k = "err: \(error)"
            }

            await progress("done")
            return report
        }
    }
#endif
