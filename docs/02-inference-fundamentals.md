# Inference fundamentals

## Request lifecycle

An autoregressive model:

1. Tokenizes the prompt.
2. Processes the prompt during **prefill**.
3. Generates tokens through repeated **decode** steps.
4. Stops at a stop condition or token limit.

Prefill processes many prompt tokens in parallel. Decode usually produces one token per active sequence per step.

## Memory

A rough lower bound for weight memory is:

```text
parameters × bytes per parameter
```

| Representation | Approximate bytes per parameter |
|---|---:|
| FP32 | 4 |
| FP16/BF16 | 2 |
| INT8 | 1 plus metadata |
| 4-bit | 0.5 plus metadata |

Serving also requires runtime memory and a KV cache.

## Context and KV cache

A request's context includes instructions, conversation history, the current prompt, and generated output. `--max-model-len` limits total sequence length.

The KV cache stores attention state for previous tokens, avoiding repeated computation during decode. Its memory use grows with model shape, token count, active sequences, and datatype.

## Serving metrics

| Metric | Meaning |
|---|---|
| TTFT | Time from request arrival to first token |
| TPOT | Average time per output token after the first |
| ITL | Delay between output tokens |
| End-to-end latency | Total request duration |
| Token throughput | Tokens processed per second |
| Request throughput | Requests completed per second |

Use fixed input/output lengths, warm-up requests, and percentiles when comparing serving configurations.

## Batching

vLLM can combine work from active requests through continuous batching. This improves aggregate utilization, but single-request latency and multi-request throughput should be measured separately.
