import Foundation
import XCTest

@testable import b0tCore
@testable import b0tLlama

/// Host-side **functional** half of the §14 Q6 validation, for the remote
/// (no-device) workflow. Runs the resource-independent checks — #1 template
/// gate, #5 GBNF structured-output validity, #6 tool-call hit-rate — against the
/// real trio Q4_K_M GGUFs on the macOS host (the xcframework's macOS slice).
///
/// This gives genuine go/no-go + tool-call-competence signal remotely. It does
/// NOT measure RAM/latency (#2/#3/#4) — those are host-meaningless and stay for
/// the physical iPhone 13 Pro pass.
///
/// Gated by `Q6_HOST=1`. Expects the trio pre-downloaded (pinned + verified) to
/// `~/Library/Caches/b0t-tests/models/` (see `/tmp/q6_download.sh`).
final class Q6HostFunctionalTests: XCTestCase {
    private struct Model {
        let label: String
        let file: String
    }

    private static let trio: [Model] = [
        .init(label: "Qwen3-1.7B", file: "Qwen_Qwen3-1.7B-Q4_K_M.gguf"),
        .init(label: "Llama-3.2-1B", file: "Llama-3.2-1B-Instruct-Q4_K_M.gguf"),
        .init(label: "Qwen2.5-1.5B", file: "Qwen2.5-1.5B-Instruct-Q4_K_M.gguf"),
    ]

    private static var modelsDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("b0t-tests/models", isDirectory: true)
    }

    func test_functionalValidation_printsResultsTable() async throws {
        guard ProcessInfo.processInfo.environment["Q6_HOST"] == "1" else {
            throw XCTSkip("Q6_HOST != 1 — skipping host functional validation")
        }

        var rows: [String] = []
        rows.append("model | template-gate | GBNF JSON (n/5) | tool-call hit | parsed")

        for model in Self.trio {
            let path = Self.modelsDir.appendingPathComponent(model.file)
            guard FileManager.default.fileExists(atPath: path.path) else {
                rows.append("\(model.label) | MISSING (\(model.file)) | — | — | —")
                continue
            }

            let runtime: LlamaRuntime
            do {
                runtime = try LlamaRuntime(modelPath: path, contextLength: 4096)
            } catch {
                rows.append("\(model.label) | LOAD FAILED: \(error) | — | — | —")
                continue
            }

            // #1 template gate.
            let gate: String
            do {
                let rendered = try await runtime.renderChatTemplate([
                    .init(role: "system", content: "S"),
                    .init(role: "user", content: "U"),
                ])
                let head = rendered.prefix(24).replacingOccurrences(of: "\n", with: "⏎")
                gate = "PASS [\(head)…]"
            } catch {
                gate = "FAIL — DISQUALIFIED"
            }

            // #5 GBNF structured output (5 trials).
            let engine = LlamaEngine(runtimeReusing: runtime)
            var ok = 0
            for _ in 0..<5 {
                let ctx = AssembledContext(
                    systemInstructions: "You are a terse assistant.",
                    userPrompt: "Greet the user in one short sentence.",
                    tools: [],
                    budget: .init(
                        estimated: 0, limit: 4096, breakdown: [:], didFallBackToDigest: false),
                    loadedFiles: [])
                if (try? await engine.generate(context: ctx, generating: ConversationResponse.self))
                    != nil
                {
                    ok += 1
                }
            }

            // #6 tool-call hit-rate over the fixed probe set.
            let loop = LlamaToolCallLoop(runtime: runtime)
            var results: [(probe: ToolCallProbe, call: ToolCallEnvelope?)] = []
            for probe in Q6ToolCallFixtures.probes {
                let call = try? await loop.pickTool(
                    userPrompt: probe.prompt, tools: Q6ToolCallFixtures.descriptors)
                results.append((probe, call))
            }
            let score = Q6ToolCallFixtures.score(results)

            rows.append(
                "\(model.label) | \(gate) | \(ok)/5 | "
                    + String(
                        format: "%d/%d (%.0f%%)", score.correctTool, score.total,
                        score.hitRate * 100)
                    + " | \(score.parsed)/\(score.total)")
        }

        print("\n===== Q6 HOST FUNCTIONAL RESULTS =====")
        for r in rows { print(r) }
        print("======================================\n")
    }
}
