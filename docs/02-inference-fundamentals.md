# Inference fundamentals

## Request path

```text
prompt -> tokenize -> prefill -> repeated decode -> stop
```

- **Prefill** processes prompt tokens in parallel.
- **Decode** usually emits one token per active sequence per step.
- **Continuous batching** combines work from multiple active requests.

## Memory

Weight memory starts near `parameters × bytes per parameter`:

| Format | Approximate bytes/parameter |
|---|---:|
| FP32 | 4 |
| FP16/BF16 | 2 |
| INT8 | 1 + metadata |
| 4-bit | 0.5 + metadata |

Real serving also needs runtime memory and the **KV cache**. KV-cache usage grows
with model shape, active sequences, context length, and datatype.

## Metrics to remember

| Metric | Meaning |
|---|---|
| TTFT | Request to first token |
| TPOT / ITL | Delay between generated tokens |
| End-to-end latency | Request to completion |
| Token throughput | Tokens processed per second |
| Request throughput | Requests completed per second |

For useful comparisons, fix input/output lengths and concurrency, warm up first,
and report percentiles—not only averages.
