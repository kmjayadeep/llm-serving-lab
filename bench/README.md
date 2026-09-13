# Local vLLM benchmark

This benchmark is a closed-loop HTTP load generator for an already-running
vLLM OpenAI-compatible server. It does not start, stop, or reconfigure vLLM.

## Protocol

- Run one model at a time with identical vLLM settings.
- Test concurrency `1, 2, 4, 8, 16` in that order.
- Before each measured scenario, issue three unmeasured warm-up requests.
- Issue 50 measured requests per scenario.
- Stream responses and measure TTFT at the first non-empty content delta.
- Request exactly 128 output tokens by setting vLLM's `ignore_eos` extension.
- Save every request as JSONL and scenario aggregates as CSV.

This is a **closed-loop** test: each worker sends its next request after its
previous request completes. The concurrency value is therefore the maximum
number of in-flight requests, not a fixed arrival rate.

## Metrics

- **TTFT:** request start to first non-empty streamed content delta.
- **End-to-end latency:** request start to completion of the response stream.
- **Per-request output tokens/sec:** `(completion_tokens - 1) / (end - first token)`.
- **Aggregate output tokens/sec:** successful completion tokens / scenario duration.
- **Requests/sec:** successful requests / scenario duration.
- **Error rate:** failed requests / attempted requests.

Summary output includes mean, p50, p95, and p99 latency and TTFT. With only 50
samples, p99 is directional rather than statistically robust.

## Environment preparation

Use an isolated Python environment and install `bench/requirements.txt`. Start
the vLLM service separately, selecting one of the model IDs declared in
`scenarios.yaml`.

The intended invocation for each running model is:

```text
python bench/load.py --model Qwen/Qwen2.5-0.5B-Instruct
python bench/load.py --model Qwen/Qwen2.5-3B-Instruct
```

Do not run both commands against a server that only loaded one model. The tool
checks `/v1/models` and exits if the requested model is not currently served.

## Results

Each run creates:

```text
bench/results/<UTC timestamp>-<model>/
├── metadata.json
├── raw.jsonl
└── summary.csv
```

`metadata.json` captures the scenario configuration and client environment.
Before publishing a baseline, also record the vLLM image, launch arguments,
GPU, ROCm version, and GPU idle state alongside the generated files.

Do not compare runs if any of these changed:

- vLLM image or launch arguments
- dtype or quantization
- maximum model length or GPU-memory utilization
- prompt set or generation settings
- competing GPU workload
- warm-up and measured request counts
