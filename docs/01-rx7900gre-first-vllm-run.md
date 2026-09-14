# First vLLM run on RX 7900 GRE

**Result:** successful on 2026-09-12.

## Tested stack

| Component | Value |
|---|---|
| GPU | RX 7900 GRE, `gfx1100`, 15.98 GiB |
| Host | NixOS, `amdgpu`, x86-64 |
| Image | `rocm/vllm-dev:rocm7.2.1_navi_ubuntu24.04_py3.12_pytorch_2.9_vllm_0.16.0` |
| Model | `Qwen/Qwen2.5-0.5B-Instruct` |

The host also has an AMD iGPU. PyTorch showed the discrete GPU as device `0`,
so the run used `HIP_VISIBLE_DEVICES=0`.

## Configuration

```text
dtype=float16
max_model_len=2048
gpu_memory_utilization=0.75
enforce_eager=true
```

`--enforce-eager` trades some performance for compatibility.

## Evidence

- ROCm/PyTorch identified the RX 7900 GRE.
- vLLM loaded about 0.99 GiB of weights and started its API.
- A chat-completion request returned generated text.
- `/metrics` exposed serving metrics.

Generated text alone does not prove GPU use; always check runtime device logs.

## Baseline

Five requests, 128 input and 128 output tokens, concurrency 1:

| Output throughput | Mean TTFT | Mean TPOT | Mean latency |
|---:|---:|---:|---:|
| 103.22 tok/s | 24.93 ms | 9.57 ms | 1.24 s |

Full results: [server observations](../artifacts/2026-09-rx7900gre/server-observations.md).
