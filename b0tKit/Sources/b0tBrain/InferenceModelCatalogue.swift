import Foundation

/// Engine family for a catalogue entry. Raw values match `identity/processor.md`'s
/// `engine` vocabulary. Kept in `b0tBrain` (independent of `b0tCore`'s
/// `EngineKind`) so the catalogue stays in the markdown-data layer; `b0tCore`/C4
/// maps this to its runtime `EngineKind`.
public enum InferenceEngineFamily: String, Sendable, Codable, Equatable {
    case foundationModels = "foundation_models"
    case llama
}

/// One inference model b0t can run. Distinct from the face `BotModel` catalogue
/// (cosmetic) — this is the *engine* catalogue (§14 Q6). Download fields are nil
/// for the Foundation Models entry (no download / no checksum).
///
/// Integrity fields (`pinnedSHA`, `sha256`, `sizeBytes`) were captured + verified
/// 2026-06-02/05; see `docs/specs/phase-2c-q6-model-lineup-validation.md` §4.
public struct InferenceModelEntry: Sendable, Equatable, Identifiable {
    /// Catalogue id; matches `identity/processor.md`'s `model_id`.
    public let id: String
    public let displayName: String
    public let engine: InferenceEngineFamily
    /// Trained context window (token budget denominator).
    public let contextWindow: Int
    public let quant: String?
    /// llama.cpp chat-template family (host-confirmed for the trio). Nil for FM.
    public let templateFamily: String?
    public let license: String
    /// User-facing disclosure for the Processor inspector. **Provisional** —
    /// pending a voice-and-copy pass before the Stage D UI ships (spec §7).
    public let disclosure: String

    // Download coordinates (nil for the Foundation Models entry).
    public let repo: String?
    public let pinnedSHA: String?
    public let file: String?
    public let sha256: String?
    public let sizeBytes: Int?

    public init(
        id: String, displayName: String, engine: InferenceEngineFamily, contextWindow: Int,
        quant: String? = nil, templateFamily: String? = nil, license: String, disclosure: String,
        repo: String? = nil, pinnedSHA: String? = nil, file: String? = nil, sha256: String? = nil,
        sizeBytes: Int? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.engine = engine
        self.contextWindow = contextWindow
        self.quant = quant
        self.templateFamily = templateFamily
        self.license = license
        self.disclosure = disclosure
        self.repo = repo
        self.pinnedSHA = pinnedSHA
        self.file = file
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
    }

    /// Pinned Hugging Face download URL (`resolve/<sha>/<file>`), or nil for the
    /// Foundation Models entry. The commit SHA pins the exact revision so the
    /// downloaded bytes match `sha256` (ADR-0012 "pinned, declared source").
    public var sourceURL: URL? {
        guard let repo, let pinnedSHA, let file else { return nil }
        return URL(string: "https://huggingface.co/\(repo)/resolve/\(pinnedSHA)/\(file)")
    }
}

/// The inference-model catalogue (§14 Q6). Foundation Models default + the
/// validated downloadable trio + the SmolLM2 test fixture. Static Swift data
/// (no bundle lookup); small and fixed for v1.
public enum InferenceModelCatalogue {
    public static let foundationModelsDefault = InferenceModelEntry(
        id: "foundation_models_default",
        displayName: "Apple Foundation Models",
        engine: .foundationModels,
        contextWindow: 4096,
        license: "Apple system model",
        disclosure:
            "Apple's on-device model. Nothing downloads and nothing leaves your device.")

    public static let qwen3 = InferenceModelEntry(
        id: "qwen3-1.7b",
        displayName: "Qwen3 1.7B",
        engine: .llama,
        contextWindow: 32768,
        quant: "Q4_K_M",
        templateFamily: "ChatML",
        license: "Apache-2.0",
        disclosure: "Qwen3 1.7B — Apache 2.0, from Alibaba's Qwen team. Runs on your device.",
        repo: "bartowski/Qwen_Qwen3-1.7B-GGUF",
        pinnedSHA: "dcb19155b962dbb6389f4691a982043a8e651022",
        file: "Qwen_Qwen3-1.7B-Q4_K_M.gguf",
        sha256: "72c5c3cb38fa32d5256e2fe30d03e7a64c6c79e668ad84057e3bd66e250b24fb",
        sizeBytes: 1_282_439_584)

    public static let llama32 = InferenceModelEntry(
        id: "llama-3.2-1b",
        displayName: "Llama 3.2 1B",
        engine: .llama,
        contextWindow: 131072,
        quant: "Q4_K_M",
        templateFamily: "llama3",
        license: "Llama 3.2 Community License",
        disclosure:
            "Built with Llama. Llama 3.2 1B, from Meta, under the Llama 3.2 Community License. "
            + "Runs on your device.",
        repo: "bartowski/Llama-3.2-1B-Instruct-GGUF",
        pinnedSHA: "067b946cf014b7c697f3654f621d577a3e3afd1c",
        file: "Llama-3.2-1B-Instruct-Q4_K_M.gguf",
        sha256: "6f85a640a97cf2bf5b8e764087b1e83da0fdb51d7c9fab7d0fece9385611df83",
        sizeBytes: 807_694_464)

    public static let qwen25 = InferenceModelEntry(
        id: "qwen2.5-1.5b",
        displayName: "Qwen2.5 1.5B",
        engine: .llama,
        contextWindow: 32768,
        quant: "Q4_K_M",
        templateFamily: "ChatML",
        license: "Apache-2.0",
        disclosure: "Qwen2.5 1.5B — Apache 2.0, from Alibaba's Qwen team. Runs on your device.",
        repo: "bartowski/Qwen2.5-1.5B-Instruct-GGUF",
        pinnedSHA: "9eadc66189c7641e1ddd226b8267a9119b2ce2d4",
        file: "Qwen2.5-1.5B-Instruct-Q4_K_M.gguf",
        sha256: "1adf0b11065d8ad2e8123ea110d1ec956dab4ab038eab665614adba04b6c3370",
        sizeBytes: 986_048_768)

    /// Tiny test model (Stage B). Not part of the user-facing production lineup,
    /// but a real downloadable entry the download/lifecycle code exercises.
    public static let smolLM2Test = InferenceModelEntry(
        id: "smollm2-360m-test",
        displayName: "SmolLM2 360M (test)",
        engine: .llama,
        contextWindow: 8192,
        quant: "Q4_K_M",
        templateFamily: "ChatML",
        license: "Apache-2.0",
        disclosure: "SmolLM2 360M — Apache 2.0, from Hugging Face. Test model.",
        repo: "bartowski/SmolLM2-360M-Instruct-GGUF",
        pinnedSHA: "main",
        file: "SmolLM2-360M-Instruct-Q4_K_M.gguf",
        sha256: "2fa3f013dcdd7b99f9b237717fa0b12d75bbb89984cc1274be1471a465bac9c2",
        sizeBytes: 270_590_880)

    /// Production user-facing lineup: Foundation Models + the validated trio.
    public static let production: [InferenceModelEntry] = [
        foundationModelsDefault, qwen3, llama32, qwen25,
    ]

    /// Everything, including the test fixture.
    public static let all: [InferenceModelEntry] = production + [smolLM2Test]

    /// Entries that require a download (the llama models).
    public static var downloadable: [InferenceModelEntry] {
        all.filter { $0.engine == .llama }
    }

    public static func entry(id: String) -> InferenceModelEntry? {
        all.first { $0.id == id }
    }
}
