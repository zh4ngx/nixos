# Local LLM evaluation: Gemma 4 12B vs Qwen 14B/30B/32B quants on RX 6900 XT

2026-08-17. Trigger: Andy's research request (routed via nixos-ag).
Scope: pick the local model strategy for `services.llama-cpp` on MS-7E51.
All "measured" numbers below come from this host on 2026-08-17 unless noted.
"Est" marks figures derived from formulas or public quant tables, not measured
here; model-lineup knowledge has a training cutoff — verify exact GGUF sizes
on Hugging Face before downloading.

## Hardware constraints (measured)

| Item | Value | Source |
|---|---|---|
| GPU VRAM total | 16.0 GiB (17,163,091,968 B) | `/sys/class/drm/card1/device/mem_info_vram_total` |
| Idle VRAM (desktop + compositor running) | 3.0 GiB | same, with llama stopped |
| **Practical llama.cpp VRAM budget** | **~13.0 GiB** | total − idle |
| Power | 292 W board cap (OCP mitigation, active) | `gpu-power-cap.service` |
| Backend | Vulkan, `pkgs.llama-cpp-vulkan`, full layer offload | `hosts/MS-7E51/default.nix` |
| Disk free | 1.5 TiB | `/` |

## Current setup, measured today

- Model: `gemma-4-12b-it-qat-q4_0.gguf` (6.48 GiB weights, 11.91 B params) + 167 MiB mmproj.
- Config: 32k ctx, KV q8_0, flash-attn auto, parallel 1, ngl 99.
- **Throughput (llama-bench, Vulkan, q8_0 KV, fa): pp512 = 1454 t/s, tg128 = 55.25 t/s** (matches the 55 t/s / 1400 t/s reported by nixos-ag earlier).
- **Total VRAM at 32k ctx: 10.2 GiB** (weights + KV + buffers). Headroom above current: ~2.8 GiB.
- Stress: box survived 32-thread CPU + GPU torture tests after the 18:21 PSU trip; torture passed with the 292 W cap in place.

## Candidate sizing (est)

Weights are Q4_K_M-class file sizes from public quant tables (±5%); KV q8_0
per token = `2 × layers × kv_heads × head_dim × 1 byte` (q8_0 ≈ half of fp16).

| Model | Weights | KV q8_0 @32k | Est total | Fits ~13 GiB? |
|---|---|---|---|---|
| Gemma 4 12B Q4_0 (current) | 6.5 GiB | ~2.6 GiB (implied) | 10.2 GiB (measured) | Yes, 2.8 spare |
| Qwen3-14B Q4_K_M | ~9.0 GiB | ~2.6 GiB (40L×8KV×128hd) | ~12.6 GiB | **Borderline yes** (16k ctx → ~11.3) |
| Qwen2.5-Coder-14B Q4_K_M | ~9.0 GiB | ~3.0 GiB (48L×8KV×128hd) | ~13.0 GiB | Borderline; 16k ctx → ~11.5 |
| Qwen3-30B-A3B Q4_K_M (MoE) | ~18.6 GiB | — | — | **No** (weights alone) |
| Qwen3-30B-A3B IQ4_XS | ~16.3 GiB | — | — | **No** |
| Qwen3-30B-A3B Q3_K_M | ~14.7 GiB | ~1.5 GiB (48L×4KV×128hd) | ~16.9+ GiB | **No** |
| Qwen3-32B / Qwen2.5-Coder-32B Q4_K_M | ~19.8 GiB | ~8.2 GiB (64L×8KV×128hd) | — | **No** |

Note on "27B/32B": no 27B Qwen exists in my knowledge (lineup is 32B dense,
30B-A3B MoE, 14B, 8B); sizes above cover the class either way. Gemma 4 itself
is newer than my cutoff — its measured numbers here are host-truth, arch
details are not independently verified.

### Partial CPU offload penalty (est, not measured)

A 30B/32B Q4 at ~60-70% layers on GPU would move ~6-8 GiB of weights to
system RAM with per-token PCIe round-trips. On Vulkan/RDNA2 that typically
lands at 4-9 t/s generation and double-digit-t/s prefill — a 6-14× regression
versus the current 55 t/s. Not usable for interactive chat; not recommended.

### Expected throughput if upgraded to a 14B Q4_K_M (est)

Generation is memory-bandwidth-bound: 9.0 GiB reads/token vs 6.5 today →
~40 t/s (est, range 35-45). Prefill stays compute-bound, est 1000-1200 t/s.
MoE 30B-A3B, if it fit, would generate fast (3.3B active), but it does not
fit at any usable quant; fitting it requires a 24 GB card.

## Trade-off matrix

| Option | VRAM | tg t/s | 32k ctx | Coding/reasoning | Verdict |
|---|---|---|---|---|---|
| Keep Gemma 4 12B Q4_0 | 10.2/13 | **55 (measured)** | Yes | Good general chat; multimodal (mmproj) | **Keep as default** |
| Qwen3-14B Q4_K_M | ~12.6/13 | ~40 est | 16k comfortable, 32k tight | Stronger reasoning/tools; no vision | Best test candidate |
| Qwen2.5-Coder-14B Q4_K_M | ~13.0/13 | ~38 est | 16k | Best code completion class | Test if coding-first |
| 30B/32B class any quant | over | — | — | — | Rejected: does not fit 16 GB |

## Recommendation

1. **Keep Gemma 4 12B QAT Q4_0 as the always-on default.** It is measured,
   multimodal, has 2.8 GiB headroom at 32k, and the PSU/OCP history argues
   against pushing the card harder than necessary.
2. **Evaluate Qwen3-14B Q4_K_M as the coding/reasoning candidate** — the only
   meaningful upgrade class that fits. If chosen: set `ctx-size = 16384`
   initially (KV headroom), KV q8_0 stays, drop `mmproj`. Run the bench first
   (below); only switch `services.llama-cpp.model` if measured tg ≥ ~35 t/s.
3. **Do not pursue 30B/32B or MoE quants on this card** — no quant fits with
   a usable context; partial offload destroys interactivity. Revisit when the
   GPU is ≥24 GB.
4. Either way, keep the non-autostart trip-safety posture (`wantedBy = []`).

## Test plan (Qwen3-14B Q4_K_M, ~9 GB download)

```fish
# download (HF token if needed)
nix shell nixpkgs#huggingface-cli -- huggingface-cli download \
  Qwen/Qwen3-14B-GGUF qwen3-14b-q4_k_m.gguf --local-dir ~/models/qwen3-14b-q4_k_m

# bench on this exact host/backend
nix shell nixpkgs#llama-cpp-vulkan -- llama-bench \
  -m ~/models/qwen3-14b-q4_k_m/qwen3-14b-q4_k_m.gguf \
  -ngl 99 -fa 1 -ctk q8_0 -ctv q8_0 -p 512 -n 128 -r 2
# then VRAM sanity at target ctx:
nix shell nixpkgs#llama-cpp-vulkan -- llama-server -m <model> -ngl 99 -c 16384 \
  --parallel 1 -ctk q8_0 -ctv q8_0 -fa auto --port 18081 &
cat /sys/class/drm/card1/device/mem_info_vram_used   # must stay < ~13.5 GiB
```

Config delta if it wins: `model` path, drop `mmproj`, `ctx-size = 16384`,
everything else unchanged.
