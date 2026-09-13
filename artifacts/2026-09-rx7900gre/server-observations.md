# Server observations

Captured and sanitized during the first experiment on 2026-09-12.

## Software

| Component | Version or value |
|---|---|
| Image | `rocm/vllm-dev:rocm7.2.1_navi_ubuntu24.04_py3.12_pytorch_2.9_vllm_0.16.0` |
| Reported vLLM build | `0.16.1.dev0+g89a77b108.d20260317` |
| Model | `Qwen/Qwen2.5-0.5B-Instruct` |

## Configuration

```text
dtype=float16
max_model_len=2048
gpu_memory_utilization=0.75
enforce_eager=true
HIP_VISIBLE_DEVICES=0
```

## Selected log observations

```text
Resolved architecture: Qwen2ForCausalLM
Casting torch.bfloat16 to torch.float16
Using Triton Attention backend
Model loading took 0.99 GiB memory
Available KV cache memory: 9.25 GiB
GPU KV cache size: 808,192 tokens
Maximum concurrency for 2,048 tokens per request: 394.62x
Application startup complete
```

The reported concurrency is theoretical cache capacity, not a measured throughput result.

## API result

`POST /v1/chat/completions` returned HTTP success and a valid chat completion:

| Metric | Value |
|---|---:|
| Prompt tokens | 46 |
| Completion tokens | 20 |
| Total tokens | 66 |

## Controlled serving benchmark

A later benchmark used one warm-up request followed by five measured requests. Each request had 128 random input tokens and exactly 128 output tokens, with maximum concurrency set to one.

| Metric | Result |
|---|---:|
| Successful requests | 5/5 |
| Benchmark duration | 6.20 s |
| Output throughput | 103.22 tokens/s |
| Peak output throughput | 105.00 tokens/s |
| Mean time to first token | 24.93 ms |
| Mean time per output token | 9.57 ms |
| Mean inter-token latency | 9.49 ms |
| Mean end-to-end latency | 1239.91 ms |
| P99 end-to-end latency | 1247.67 ms |

This showed that vLLM's periodic idle-window throughput log was not a request-level benchmark. Fixed-length requests, warmups, and latency distributions gave a more useful baseline.

## Lightweight UI and proxy

A static browser client was packaged in a local NGINX Alpine image:

| Observation | Result |
|---|---|
| Built image size | Approximately 26 MB |
| UI health | `GET /health` returned `200` |
| Model discovery | Proxied `/v1/models` returned the Qwen model |
| Metrics | Proxied `/metrics` returned vLLM metrics |
| Browser test | Model selector populated and server metrics rendered |

NGINX serves the page on `127.0.0.1:3001` and proxies API traffic to vLLM on port 8000. Streaming proxy buffering is disabled.
