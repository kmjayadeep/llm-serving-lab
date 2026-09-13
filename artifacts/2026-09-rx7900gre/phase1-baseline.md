# Phase 1 local vLLM baseline

Captured on 2026-09-13 on the RX 7900 GRE.

## Configuration

| Setting | Value |
|---|---|
| vLLM image | `rocm/vllm-dev:rocm7.2.1_navi_ubuntu24.04_py3.12_pytorch_2.9_vllm_0.16.0` |
| dtype | `float16` |
| maximum model length | 2,048 tokens |
| GPU memory utilization | 0.75 |
| execution mode | eager |
| prompt tokens | 75 |
| requested output tokens | 128 |
| measured requests | 50 per concurrency |
| warm-up requests | 3 per concurrency |
| workload | closed-loop streaming requests |

Each request produced exactly 128 output tokens, and all 500 measured requests
completed successfully. The server was restarted between models. Model loading
and benchmark warm-ups are excluded from measured results.

## Qwen2.5-0.5B-Instruct

| Concurrency | Requests/s | Aggregate output tokens/s | Mean request output tokens/s | Mean TTFT | P95 TTFT | Mean latency | P95 latency | Error rate |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0.809 | 103.600 | 104.785 | 23.419 ms | 24.134 ms | 1,235.504 ms | 1,247.492 ms | 0% |
| 2 | 1.601 | 204.912 | 104.016 | 28.288 ms | 33.472 ms | 1,249.287 ms | 1,256.396 ms | 0% |
| 4 | 3.055 | 391.079 | 103.456 | 31.566 ms | 35.070 ms | 1,259.162 ms | 1,265.666 ms | 0% |
| 8 | 5.617 | 718.975 | 102.426 | 34.187 ms | 37.035 ms | 1,274.131 ms | 1,279.836 ms | 0% |
| 16 | 8.986 | 1,150.242 | 101.262 | 179.374 ms | 503.719 ms | 1,434.370 ms | 1,749.119 ms | 0% |

## Qwen2.5-3B-Instruct

| Concurrency | Requests/s | Aggregate output tokens/s | Mean request output tokens/s | Mean TTFT | P95 TTFT | Mean latency | P95 latency | Error rate |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0.197 | 25.279 | 25.315 | 44.296 ms | 45.256 ms | 5,063.465 ms | 5,092.906 ms | 0% |
| 2 | 0.408 | 52.201 | 26.311 | 75.804 ms | 78.689 ms | 4,903.348 ms | 5,010.103 ms | 0% |
| 4 | 0.797 | 102.021 | 26.764 | 77.096 ms | 83.023 ms | 4,822.452 ms | 4,887.272 ms | 0% |
| 8 | 1.457 | 186.547 | 26.353 | 82.890 ms | 89.960 ms | 4,901.998 ms | 4,911.788 ms | 0% |
| 16 | 2.277 | 291.440 | 23.689 | 296.528 ms | 702.559 ms | 5,661.576 ms | 6,011.649 ms | 0% |

## Initial observations

- The 0.5B model sustained about 104 output tokens/s per request through
  concurrency 8. At concurrency 16, aggregate throughput continued to increase,
  but TTFT and tail latency rose sharply.
- The 3B model delivered about 25–27 output tokens/s per request through
  concurrency 8. Concurrency 16 increased aggregate throughput while reducing
  per-request decode speed and substantially increasing TTFT and latency.
- For both models, concurrency 8 is the highest tested level before a clear
  latency knee. This is an initial baseline, not yet a sustainable-capacity
  conclusion.

## Raw results

- `bench/results/20260913T202424Z-Qwen2.5-0.5B-Instruct/`
- `bench/results/20260913T203420Z-Qwen2.5-3B-Instruct/`

P99 values are available in each run's `summary.csv`. With 50 requests per
scenario, tail percentiles should be treated as directional.
