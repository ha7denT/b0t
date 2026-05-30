import Foundation
import llama

/// Thin b0t-owned wrapper over the llama.cpp C API. Loads one GGUF model and
/// its context, applies the model's embedded chat template, and generates text
/// — optionally constrained by a GBNF grammar. One resident model per instance.
///
/// An `actor` so the non-Sendable C context pointers never cross threads
/// unsynchronised. Model/context are freed in `deinit`.
///
/// The llama.cpp backend (`llama_backend_init`) is process-global. We initialise
/// it once on first runtime construction and intentionally never call
/// `llama_backend_free` — for a single resident model the cost of leaving it
/// initialised for process lifetime is negligible, and a shared free would race
/// other live instances. Stage C revisits this if multiple engines coexist.
public actor LlamaRuntime {
    /// The model's trained context length (from GGUF metadata), used as the
    /// token-budget denominator by callers.
    public nonisolated let contextWindow: Int

    private let model: OpaquePointer
    private let context: OpaquePointer
    private let vocab: OpaquePointer

    private static let backendInit: Void = {
        llama_backend_init()
    }()

    /// Loads `modelPath` and creates a context of `contextLength` tokens
    /// (clamped to the model's trained maximum).
    public init(modelPath: URL, contextLength: Int) throws {
        _ = LlamaRuntime.backendInit

        var modelParams = llama_model_default_params()
        // CPU-only on the host test runner; GPU offload is a Stage C tuning knob.
        modelParams.n_gpu_layers = 0

        guard
            let model = modelPath.path.withCString({ cPath in
                llama_model_load_from_file(cPath, modelParams)
            })
        else {
            throw LlamaRuntimeError.modelLoadFailed(path: modelPath.path)
        }

        let trained = Int(llama_model_n_ctx_train(model))
        let resolved = max(1, min(contextLength, trained))

        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = UInt32(resolved)
        ctxParams.n_batch = UInt32(resolved)

        guard let context = llama_init_from_model(model, ctxParams) else {
            llama_model_free(model)
            throw LlamaRuntimeError.contextCreationFailed
        }

        guard let vocab = llama_model_get_vocab(model) else {
            llama_free(context)
            llama_model_free(model)
            throw LlamaRuntimeError.contextCreationFailed
        }

        self.model = model
        self.context = context
        self.vocab = vocab
        self.contextWindow = trained
    }

    isolated deinit {
        llama_free(context)
        llama_model_free(model)
    }

    /// Applies the model's embedded chat template to `messages`, tokenizes,
    /// and generates until EOG or `maxTokens`. If `grammar` is non-nil, a GBNF
    /// grammar sampler constrains output to it (root rule "root").
    public func generate(
        messages: [LlamaChatMessage],
        grammar: String?,
        maxTokens: Int
    ) async throws -> String {
        let prompt = try applyChatTemplate(messages)
        let tokens = tokenize(prompt, addSpecial: true)

        let sampler = try makeSampler(grammar: grammar)
        defer { llama_sampler_free(sampler) }

        // Decode the prompt as a single batch.
        var promptTokens = tokens
        let batch = promptTokens.withUnsafeMutableBufferPointer { buf in
            llama_batch_get_one(buf.baseAddress, Int32(buf.count))
        }
        let promptCode = llama_decode(context, batch)
        if promptCode != 0 {
            throw LlamaRuntimeError.decodeFailed(code: promptCode)
        }

        var output = ""
        var generated = 0
        while generated < maxTokens {
            let tokenID = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, tokenID) { break }

            output += piece(for: tokenID)
            generated += 1

            // Feed the sampled token back in for the next step.
            var next = tokenID
            let nextBatch = withUnsafeMutablePointer(to: &next) { ptr in
                llama_batch_get_one(ptr, 1)
            }
            let code = llama_decode(context, nextBatch)
            if code != 0 {
                throw LlamaRuntimeError.decodeFailed(code: code)
            }
        }
        return output
    }

    // MARK: - C bridging helpers

    private func applyChatTemplate(_ messages: [LlamaChatMessage]) throws -> String {
        let tmpl = llama_model_chat_template(model, nil)

        // Bridge each message's role/content into C strings whose lifetimes
        // span the apply call.
        func withCMessages<R>(
            _ index: Int,
            _ acc: [llama_chat_message],
            _ body: ([llama_chat_message]) throws -> R
        ) rethrows -> R {
            if index == messages.count { return try body(acc) }
            return try messages[index].role.withCString { rolePtr in
                try messages[index].content.withCString { contentPtr in
                    var next = acc
                    next.append(llama_chat_message(role: rolePtr, content: contentPtr))
                    return try withCMessages(index + 1, next, body)
                }
            }
        }

        return try withCMessages(0, []) { cMessages in
            var capacity = max(256, cMessages.reduce(0) { $0 + ($1.content.map { strlen($0) } ?? 0) } * 2)
            var buffer = [CChar](repeating: 0, count: capacity)
            var written = cMessages.withUnsafeBufferPointer { msgPtr in
                llama_chat_apply_template(
                    tmpl, msgPtr.baseAddress, msgPtr.count, true, &buffer, Int32(capacity))
            }
            if written < 0 {
                throw LlamaRuntimeError.templateApplyFailed
            }
            if Int(written) > capacity {
                capacity = Int(written) + 1
                buffer = [CChar](repeating: 0, count: capacity)
                written = cMessages.withUnsafeBufferPointer { msgPtr in
                    llama_chat_apply_template(
                        tmpl, msgPtr.baseAddress, msgPtr.count, true, &buffer, Int32(capacity))
                }
                if written < 0 {
                    throw LlamaRuntimeError.templateApplyFailed
                }
            }
            let bytes = buffer[0..<Int(written)].map { UInt8(bitPattern: $0) }
            return String(decoding: bytes, as: UTF8.self)
        }
    }

    private func tokenize(_ text: String, addSpecial: Bool) -> [llama_token] {
        let utf8Count = Int32(text.utf8.count)
        // Worst case: one token per byte, plus room for special tokens.
        let maxTokens = Int(utf8Count) + 16
        var tokens = [llama_token](repeating: 0, count: maxTokens)
        let count = text.withCString { cText in
            tokens.withUnsafeMutableBufferPointer { buf in
                llama_tokenize(
                    vocab, cText, utf8Count, buf.baseAddress, Int32(buf.count), addSpecial, true)
            }
        }
        if count < 0 {
            // Buffer too small: -count is the required size; retry once.
            let needed = Int(-count)
            tokens = [llama_token](repeating: 0, count: needed)
            let second = text.withCString { cText in
                tokens.withUnsafeMutableBufferPointer { buf in
                    llama_tokenize(
                        vocab, cText, utf8Count, buf.baseAddress, Int32(buf.count), addSpecial, true)
                }
            }
            return Array(tokens[0..<max(0, Int(second))])
        }
        return Array(tokens[0..<Int(count)])
    }

    private func piece(for token: llama_token) -> String {
        var buffer = [CChar](repeating: 0, count: 64)
        let count = buffer.withUnsafeMutableBufferPointer { buf in
            llama_token_to_piece(vocab, token, buf.baseAddress, Int32(buf.count), 0, false)
        }
        if count < 0 {
            let needed = Int(-count)
            buffer = [CChar](repeating: 0, count: needed)
            let second = buffer.withUnsafeMutableBufferPointer { buf in
                llama_token_to_piece(vocab, token, buf.baseAddress, Int32(buf.count), 0, false)
            }
            guard second > 0 else { return "" }
            let bytes = buffer[0..<Int(second)].map { UInt8(bitPattern: $0) }
            return String(decoding: bytes, as: UTF8.self)
        }
        guard count > 0 else { return "" }
        let bytes = buffer[0..<Int(count)].map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private func makeSampler(grammar: String?) throws -> UnsafeMutablePointer<llama_sampler> {
        let params = llama_sampler_chain_default_params()
        guard let chain = llama_sampler_chain_init(params) else {
            throw LlamaRuntimeError.contextCreationFailed
        }
        if let grammar, !grammar.isEmpty {
            // Grammar-constrained generation: grammar first (masks invalid
            // tokens), then a repetition penalty to break greedy loops on
            // small models (SmolLM2-360M gets stuck repeating tokens without
            // it), then greedy (argmax). Fully deterministic — no temperature,
            // no stochastic dist — which eliminates flaky JSON output.
            let grammarSampler = grammar.withCString { gPtr in
                "root".withCString { rootPtr in
                    llama_sampler_init_grammar(vocab, gPtr, rootPtr)
                }
            }
            if let grammarSampler {
                llama_sampler_chain_add(chain, grammarSampler)
            }
            // Penalise recently generated tokens to prevent greedy repetition
            // loops. penalty_last_n=64, penalty_repeat=1.1 is a mild penalty
            // that breaks infinite loops without suppressing content generation;
            // freq/present penalties remain off.
            llama_sampler_chain_add(chain, llama_sampler_init_penalties(64, 1.1, 0.0, 0.0))
            llama_sampler_chain_add(chain, llama_sampler_init_greedy())
        } else {
            // Free-text generation: stochastic sampling with temperature.
            llama_sampler_chain_add(chain, llama_sampler_init_temp(0.7))
            llama_sampler_chain_add(chain, llama_sampler_init_dist(LLAMA_DEFAULT_SEED))
        }
        return chain
    }
}
