import Foundation
import FoundationModels

/// The set of inference engines b0t can use.
///
/// `EngineKind` is the runtime tag; the full engine instance is constructed
/// later (in `b0tApp` / Stage C4) once the resolved kind is known.
public enum EngineKind: Sendable, Equatable {
    /// Apple's on-device Foundation Models engine (`FoundationModelsEngine`).
    case foundationModels

    /// A llama.cpp-backed engine (`LlamaEngine` from `b0tLlama`).
    ///
    /// Note: whether the selected llama model is actually downloaded is
    /// checked in Stage C4. C2 resolves only the declared engine vs. FM
    /// availability; model-presence gating is added later.
    case llama
}

/// The result of `CapabilityDetector.resolve`.
public struct EngineResolution: Sendable, Equatable {
    /// The effective engine to use.
    public let engine: EngineKind

    /// `true` when the declared choice was overridden because it was not
    /// runnable (e.g. declared `foundation_models` but FM is unavailable).
    public let didFallBack: Bool

    public init(engine: EngineKind, didFallBack: Bool) {
        self.engine = engine
        self.didFallBack = didFallBack
    }
}

/// Resolves the *effective* engine from the declared choice in
/// `identity/processor.md` and device capability state.
///
/// ## Resolution rules (C2 — model-presence gate added in C4)
///
/// | declared            | FM available | result              | didFallBack |
/// |---------------------|--------------|---------------------|-------------|
/// | `foundation_models` | `true`       | `.foundationModels` | `false`     |
/// | `foundation_models` | `false`      | `.llama`            | `true`      |
/// | `llama`             | (any)        | `.llama`            | `false`     |
///
/// The "is the llama model actually downloaded" gate is added in Stage C4.
///
/// ## Testability seam
///
/// `resolve(declared:fmAvailable:)` takes an explicit `fmAvailable` `Bool` so
/// tests never depend on the host device's Foundation Models state. The
/// production entry point `resolve(declared:)` reads
/// `SystemLanguageModel.default.isAvailable` and forwards to the testable
/// overload.
public enum CapabilityDetector: Sendable {
    /// Production entry point. Reads `SystemLanguageModel.default.isAvailable`.
    public static func resolve(declared: EngineKind) -> EngineResolution {
        resolve(declared: declared, fmAvailable: SystemLanguageModel.default.isAvailable)
    }

    /// Testable overload. Inject `fmAvailable` to avoid host-state dependency.
    public static func resolve(declared: EngineKind, fmAvailable: Bool) -> EngineResolution {
        switch declared {
        case .foundationModels:
            if fmAvailable {
                return EngineResolution(engine: .foundationModels, didFallBack: false)
            } else {
                return EngineResolution(engine: .llama, didFallBack: true)
            }
        case .llama:
            return EngineResolution(engine: .llama, didFallBack: false)
        }
    }
}
