# First vLLM run on RX 7900 GRE

**Date:** 2026-09-12  
**Result:** Successful

## Environment

| Component | Value |
|---|---|
| GPU | AMD Radeon RX 7900 GRE |
| Architecture | Navi 31, `gfx1100` |
| VRAM | 15.98 GiB |
| Host | NixOS, x86-64 |
| Kernel driver | `amdgpu` |
| Compute devices | `/dev/kfd`, `/dev/dri/renderD*` |
| Image | `rocm/vllm-dev:rocm7.2.1_navi_ubuntu24.04_py3.12_pytorch_2.9_vllm_0.16.0` |
| Model | `Qwen/Qwen2.5-0.5B-Instruct` |

The host exposes a discrete GPU and an integrated AMD GPU. `HIP_VISIBLE_DEVICES=0` selected the RX 7900 GRE after verifying device order with `rocminfo` and PyTorch.

## Serving configuration

```text
dtype=float16
max_model_len=2048
gpu_memory_utilization=0.75
enforce_eager=true
```

`--enforce-eager` was used as a compatibility-first setting. It disables graph capture and some optimizations.

## Startup observations

```text
Resolved architecture: Qwen2ForCausalLM
Using Triton Attention backend
Model loading took 0.99 GiB memory
Available KV cache memory: 9.25 GiB
GPU KV cache size: 808,192 tokens
Application startup complete
```

## Verification

The following path completed successfully:

```text
HTTP request → vLLM → PyTorch/ROCm → RX 7900 GRE → generated response
```

Device enumeration and server logs established GPU use; generated text alone is not evidence of accelerator use.

## Benchmark

Five fixed-length requests were measured after one warm-up request. Each used 128 input tokens, 128 output tokens, and concurrency one.

| Metric | Result |
|---|---:|
| Successful requests | 5/5 |
| Output throughput | 103.22 tokens/s |
| Mean TTFT | 24.93 ms |
| Mean TPOT | 9.57 ms |
| Mean end-to-end latency | 1.24 s |

Periodic vLLM throughput logs are not request benchmarks. Fixed lengths, warmups, and latency distributions provide a more useful baseline.

Full measurements: [server observations](../artifacts/2026-09-rx7900gre/server-observations.md).

## Conclusions

- The tested ROCm/vLLM combination works on the RX 7900 GRE.
- Device selection is required on a host with both discrete and integrated AMD GPUs.
- The OpenAI-compatible API, streaming responses, and Prometheus metrics work.
- Results apply to this pinned configuration; other models, kernels, and quantization formats require separate validation.
