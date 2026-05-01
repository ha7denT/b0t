import Foundation

/// Estimates token count for a string.
///
/// Phase 2 ships a 4-chars-per-token heuristic — Apple's docs say "a single
/// token corresponds to approximately three to four characters in languages
/// like English, Spanish, or German" (see `LanguageModelSession.GenerationError.exceededContextWindowSize`).
/// 4 is the conservative upper bound for English, which biases the estimator
/// toward over-counting and triggering fallback earlier than strictly
/// necessary — better than under-counting.
///
/// If iOS exposes a public tokenizer in a future release, this estimator is
/// the single point to swap. The graduated overflow fallback in
/// `ContextAssembler` (spec §7.4) is the actual safety net — this is just
/// for budget logging and shaping.
public enum TokenEstimator {
    public static func estimate(_ text: String) -> Int {
        // Round up: a 5-character string is 2 tokens, not 1.
        let count = text.count
        return (count + 3) / 4
    }

    public static func estimate(_ texts: [String]) -> Int {
        texts.reduce(0) { $0 + estimate($1) }
    }
}
