import Foundation
import b0tBrain
import b0tCore

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
