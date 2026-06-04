# §14 Q6 — Downloadable model lineup: candidate matrix + on-device validation protocol

**Status:** Desk research complete (2026-06-02); on-device validation pending Jamee (iPhone 13 Pro / 6GB / iOS 26).
**Resolves:** PRD §12 Q12; Phase-2 spec §9 Q2/Q5; the Q6 gate on Stage C3/C4 catalogue rows.
**Decides alongside:** [ADR-0018](../decisions/0018-llama-tool-calling-via-gbnf-pure-c.md) (tool-calling via GBNF on the pure-C boundary).

> Method: a fan-out web/HF research pass (5 angles, 18 sources, 25 claims adversarially verified at 2/3-refute-to-kill) + a focused BFCL comparison + direct inspection of the pinned b9415 xcframework. Findings below are cited; figures that must be captured at lock time (checksums) or measured on hardware (RAM, latency) are flagged.

---

## 1. The recommended trio

Alongside **Apple Foundation Models** (default *when available*; the on-device fallback path is these three):

| Role | Model | Quant | Size (on disk) | Context | Template family | Tool-calling (BFCL) | License / disclosure |
|---|---|---|---|---|---|---|---|
| **Default** | **Qwen3-1.7B** | Q4_K_M | ~1.11–1.28 GB | 32,768 | ChatML | 55.49% / mt 16.9% | Apache-2.0 — NOTICE reproduction |
| **Opt-in** | **Llama 3.2 1B Instruct** | Q4_K_M | ~0.8 GB | 131,072 | `llama3` (confirmed in llama.cpp list) | weaker than Qwen3; in Meta tool lineage | Llama 3.2 Community License — "Built with Llama" |
| **Third** | **Qwen2.5-1.5B-Instruct** | Q4_K_M | ~1.12 GB | 32,768 | ChatML | 47.84% / mt 2.5% (BFCL v3) | Apache-2.0 — NOTICE reproduction |

**BFCL caveats:** scores are directional, not guarantees — off-the-shelf GGUF quants score below the cited research figures; multi-turn ("mt") is uniformly weak at this scale, so b0t should not lean on multi-turn agentic chains without on-device confirmation. Per [ADR-0018](../decisions/0018-llama-tool-calling-via-gbnf-pure-c.md), BFCL here is a *decision-competence* signal only — output **format** is GBNF-enforced, not model-dependent.

### Disqualified candidates (recorded so we don't relitigate)

| Model | Why out |
|---|---|
| **SmolLM2-1.7B** | 27% BFCL — weak tool-calling. (SmolLM2-360M stays as the offline *test* fixture only, not a catalogue row.) |
| **Qwen2.5-3B** | Better scores (50.37%) but **qwen-research / non-commercial license** — cannot ship. |
| **Gemma-3 (1B/4B)** | `gemma` family passes the chat gate, but lower BFCL (4b=39.6%, 1b=16.3%) **and** Gemma license forces Terms + Prohibited-Use passthrough to every user. Gemma **4** additionally **fails** the template gate (unsupported `<\|turn>` format). |
| **xLAM-2 (1b/3b)** | Best small tool-caller by far (3b: 58% multi-turn) but **CC-BY-NC** — non-commercial. |
| **Functionary-Small / Hermes-3-3B** | Functionary 8B too large for 6GB; Hermes-3-Llama-3.2-3B is a viable *diversity alternative* (2.02 GB, llama3 license) but its BFCL score is **unverified** — held in reserve. |

---

## 2. Per-model detail

### Default — Qwen3-1.7B
- Dense 1.7B (1.4B non-embedding), 28 layers, GQA 16Q/8KV, native 32,768 context. Apache-2.0 (the Qwen3 *series* license — NOT the restrictive Qwen-Research license other Qwen lineages use). Official card highlights agentic/tool integration with a pinned Qwen-Agent/MCP example.
- **Quant:** Q4_K_M recommended default (bartowski 1.28 GB / unsloth 1.11 GB / unsloth UD-Q4_K_XL 1.13 GB); Q5_K_M (~1.47 GB) is the quality option **if** the on-device RAM math at the target context allows.
- **Repos (well-maintained quanters):** `bartowski/Qwen_Qwen3-1.7B-GGUF`, `unsloth/Qwen3-1.7B-GGUF`.
- **Version watch:** Qwen3 has a `2507` split (Instruct-2507 = non-thinking only; Thinking-2507 = thinking only). The "both modes via `enable_thinking`" behaviour is the **original** Qwen3 dense release. Confirm which revision we pin and its mode behaviour.

### Opt-in — Llama 3.2 1B Instruct
- The `llama3` template family is **confirmed** in llama.cpp's supported list (`src/llama-chat.cpp`: `{ "llama3", LLM_CHAT_TEMPLATE_LLAMA_3 }`); the 3.1/3.2/3.3 prompt format is shared. Smaller/faster than the Qwen models (lowest RAM, fastest first-token); weaker reasoning/tool-calling.
- **Repo:** `bartowski/Llama-3.2-1B-Instruct-GGUF` (or equivalent well-maintained quanter).
- **License:** Llama 3.2 Community License — requires the **"Built with Llama"** attribution + carrying the license text. Distinct from the Apache NOTICE-only burden.

### Third — Qwen2.5-1.5B-Instruct
- ChatML template; Apache-2.0 (clean — NOTICE only); 32,768 context; Q4_K_M ~1.12 GB. Best tool-calling-per-byte of the clean-license options and the smallest serious footprint.
- **Repos:** `Qwen/Qwen2.5-1.5B-Instruct-GGUF`, `bartowski/Qwen2.5-1.5B-Instruct-GGUF`.
- **Note:** shares ChatML with Qwen3-1.7B (no *template* diversity), but adds a distinct tool-tuned lineage at minimal cost; license + competence outweigh diversity here.

---

## 3. RAM budget (6GB iPhone 13 Pro)

All three weight files (~0.8–1.3 GB at Q4_K_M) sit comfortably under the resident ceiling. **Weights are not the binding constraint — KV cache is.** KV-cache cost scales with the context window we actually run; at full 32k–40k with f16 KV it can reach several hundred MB to >1 GB. So:

- **One resident model** (existing `LlamaRuntime` invariant).
- **Do not run native max context.** Pick a usable window (candidate: 4k–8k) and **measure** peak RAM at it; consider quantized KV cache if needed.
- **Jetsam budget** on a 6GB device is roughly ~2 GB default, higher (~3–3.5 GB) **with the `com.apple.developer.kernel.increased-memory-limit` entitlement** — confirm whether b0t should carry it.
- Rough target at Q4_K_M + a few-k context: well under 2 GB resident. Confirm on hardware.

---

## 4. Pinning + integrity (ADR-0012 "pinned, declared source")

- Pin to the **full 40-char commit SHA** via `resolve/<sha>/<file>` (HF rejects 7-char short hashes).
- **Per-file SHA-256:** from HF LFS metadata (Hub API `GET /api/models/{repo}/tree/{revision}`, or the file's LFS pointer / `X-Linked-ETag`), or compute once after a trusted download and bake the expected hash into the catalogue row.

### Captured + verified (2026-06-05)

All three resolved from **bartowski** GGUF repos (open, not gated), pinned to the commit below, **downloaded and SHA-256-verified** against the pinned `resolve/<sha>/` URL. These are the catalogue rows for Stage C3.

| Model | Repo | Pinned commit | File | Size (bytes) | SHA-256 |
|---|---|---|---|---|---|
| Qwen3-1.7B | `bartowski/Qwen_Qwen3-1.7B-GGUF` | `dcb19155b962dbb6389f4691a982043a8e651022` | `Qwen_Qwen3-1.7B-Q4_K_M.gguf` | 1282439584 | `72c5c3cb38fa32d5256e2fe30d03e7a64c6c79e668ad84057e3bd66e250b24fb` |
| Llama-3.2-1B | `bartowski/Llama-3.2-1B-Instruct-GGUF` | `067b946cf014b7c697f3654f621d577a3e3afd1c` | `Llama-3.2-1B-Instruct-Q4_K_M.gguf` | 807694464 | `6f85a640a97cf2bf5b8e764087b1e83da0fdb51d7c9fab7d0fece9385611df83` |
| Qwen2.5-1.5B | `bartowski/Qwen2.5-1.5B-Instruct-GGUF` | `9eadc66189c7641e1ddd226b8267a9119b2ce2d4` | `Qwen2.5-1.5B-Instruct-Q4_K_M.gguf` | 986048768 | `1adf0b11065d8ad2e8123ea110d1ec956dab4ab038eab665614adba04b6c3370` |

---

## 5. Turnkey on-device validation protocol (iPhone 13 Pro, iOS 26)

Run per candidate (all three). **The harness is built** (2026-06-05): a DEBUG-only SwiftUI view, `Q6ValidationView` (`b0tApp/Sources/Debug/`), reached via the existing debug sheet (long-press the home screen → **Q6** in the toolbar). It `.fileImporter`-picks a GGUF, runs all six checks via `Q6Runner`, and renders the row on-screen. **Capture the numbers into the table in §6.**

**How to run:** AirDrop / save each Q4_K_M GGUF to the device's Files, open the DEBUG build, long-press home → debug brain → **Q6**, pick a model, tap *run 6 checks*, read the row. Repeat per model. The pure logic (tool-call grammar/parse/score) is host-tested in `b0tLlamaTests`; the GBNF + template-render paths have a gated `LIVE_LLAMA` e2e test (`Q6ToolCallLiveTests`).

**Setup**
1. Side-load each Q4_K_M GGUF to the device (Files / debug bundle). Note exact file + size.
2. Build with and without the `increased-memory-limit` entitlement to compare headroom.

**Per model, measure:**

| # | Check | How | Pass threshold |
|---|---|---|---|
| 1 | **Template gate (go/no-go)** | `llama_model_chat_template` + `llama_chat_apply_template` on a 2-turn message array; confirm no `templateApplyFailed` and the rendered string uses the expected delimiters (`<\|im_start\|>` / `<\|start_header_id\|>`). | Applies cleanly; correct delimiters. **Fail ⇒ disqualified** regardless of other merits. |
| 2 | **Load + peak RAM** | Load model at the chosen context window; record peak resident memory (Instruments / `os_proc_available_memory` / `task_info`). Repeat at 4k and 8k context. | No jetsam; peak leaves a safety margin under the (entitled or default) limit. Record the max safe context. |
| 3 | **First-token latency** | Warm + cold first-token time on a ~200-token prompt. | Set the per-engine target here (PRD §549 leaves the llama target to be set on first measurement). Record median over 5 runs. |
| 4 | **Throughput** | Tokens/sec, sustained generation. | Record; informational for model ranking. |
| 5 | **Structured output (GBNF)** | Run an existing `b0tCore` decision type through `LlamaEngine.generate` under its GBNF grammar; parse via `firstJSONObject` + Codable. | Valid, decodable JSON over ≥9/10 trials. |
| 6 | **Tool-call reliability (GBNF harness)** | Over a fixed set of ~10 prompts that should trigger a known `b0tModules` tool, run the GBNF tool-call loop ([ADR-0018](../decisions/0018-llama-tool-calling-via-gbnf-pure-c.md)): does the model pick the right tool + plausible args? (Format is grammar-guaranteed; we're scoring *decision* quality.) | Record hit-rate. Used to set `EngineCapabilities.supportsToolLoop` per model (tools-off below an agreed bar). |

**Decision rule:** any model failing check #1 is dropped. Among survivors, confirm RAM (#2) fits with margin and #5 is reliable; #3/#4/#6 rank/tune the lineup and set the quant (Q4_K_M vs Q5_K_M) + usable context window + per-model `supportsToolLoop`.

---

## 6. Results

### 6a. Functional half — host (macOS), 2026-06-05

 Run via the gated `Q6HostFunctionalTests` (`Q6_HOST=1`) against the verified GGUFs on the xcframework's macOS slice. **All three pass the template gate (go/no-go) and GBNF — no disqualifications.**

| Model | #1 template gate | #5 GBNF JSON (n/5) | #6 tool-call (hit / parsed) |
|---|---|---|---|
| Qwen3-1.7B | ✅ PASS — ChatML (`<\|im_start\|>`) | 5/5 | 8/8 (100%) / 8/8 |
| Llama-3.2-1B | ✅ PASS — llama3 (`<\|start_header_id\|>`) | 5/5 | 7/8 (88%) / 8/8 |
| Qwen2.5-1.5B | ✅ PASS — ChatML (`<\|im_start\|>`) | 5/5 | 8/8 (100%) / 8/8 |

**Interpretation.** Template recognition by `llama_chat_apply_template` is confirmed for the whole trio on the pure-C path — the load-bearing gate ([ADR-0018](../decisions/0018-llama-tool-calling-via-gbnf-pure-c.md)) is satisfied. GBNF structured output is reliable (also retires the llama.cpp #21571 sampler-init risk for these models). Tool-call **parse rate is 100% by grammar construction**; selection hit-rate is strong. **Caveat:** the 8 probes are simple/unambiguous, so #6 here is a *floor* check (obvious request → obvious tool), not hard agentic competence — real multi-turn/ambiguous selection will be lower (cf. the desk BFCL multi-turn figures). This validates the mechanism + basic viability of all three, not full tool-calling competence.

### 6b. Resource half — physical iPhone 13 Pro (PENDING)

Host RAM/latency are meaningless for the 6GB floor; these stay for the device pass via `Q6ValidationView`.

| Model | Max safe ctx | Peak RAM @ctx (entitled / not) | First-token median | tok/s | Verdict |
|---|---|---|---|---|---|
| Qwen3-1.7B (Q4_K_M) | pending | pending | pending | pending | functional ✅ · resource pending |
| Llama 3.2 1B (Q4_K_M) | pending | pending | pending | pending | functional ✅ · resource pending |
| Qwen2.5-1.5B (Q4_K_M) | pending | pending | pending | pending | functional ✅ · resource pending |

---

## 7. After validation → unblocks

Once the table is filled and the trio confirmed:
1. Capture pinned SHA + per-file SHA-256 per row (§4); draft each model's disclosure string for the Processor inspector and run it through the voice-and-copy guide.
2. Fill the **Stage C3** catalogue rows (`b0tBrain` inference-model catalogue), replacing the `// TODO(Q6)` placeholders.
3. Execute **Stage C3 → C4** (download manager + lifecycle + `b0tApp` engine-selection wiring), subagent-driven, as A/B/C1/C2 were.

## Open items carried forward
- Exact usable context window + quant (Q4_K_M vs Q5_K_M) — set by check #2.
- `increased-memory-limit` entitlement: adopt or not — informed by check #2.
- Per-model disclosure copy — drafted at lock time, voice-and-copy reviewed.
- `supportsToolLoop` bar — set from check #6.
