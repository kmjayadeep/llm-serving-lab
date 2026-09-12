# Inference fundamentals

## Training versus inference

Training updates model parameters by computing gradients. Inference keeps parameters fixed and uses them to predict tokens. This lab focuses on inference and serving rather than model training.

An autoregressive language model repeatedly:

1. Tokenizes input text.
2. Runs a **prefill** pass over the prompt.
3. Selects the next token.
4. Runs repeated **decode** steps, usually one new token per sequence per step.
5. Stops at a stop token, stop sequence, or configured limit.

Prefill is comparatively compute-heavy and parallel. Decode repeatedly reads model weights and KV-cache state, so memory bandwidth and scheduling are especially important.

## Parameters, precision, and weight memory

A rough lower bound for weight memory is:

```text
number of parameters × bytes per parameter
```

Typical approximations:

| Representation | Approximate bytes/parameter |
|---|---:|
| FP32 | 4 |
| FP16/BF16 | 2 |
| INT8 | 1 plus metadata/scales |
| 4-bit | 0.5 plus metadata/scales |

A 7B model in FP16 therefore needs roughly 14 GB for weights alone. Real serving also needs runtime workspaces, temporary tensors, framework state, and KV cache.

Quantization reduces weight memory and often memory bandwidth, but support and speed depend on the exact accelerator, kernel, model, and quantization format. A format being loadable does not guarantee that it is fast.

## Tokens and context

Models consume tokens rather than characters. A request's context commonly includes:

- System instructions
- Conversation history
- Current user prompt
- Generated output

`--max-model-len` bounds the total sequence length supported by a request. Longer context consumes more KV-cache memory and can reduce concurrency.

## KV cache

Transformer attention needs keys and values from earlier tokens. During serving, vLLM stores these tensors in a **KV cache** rather than recomputing them for every generated token.

KV-cache size grows with factors including:

- Number of layers
- Hidden/head dimensions
- Number of cached tokens
- Cache datatype
- Number of active sequences

vLLM's PagedAttention-inspired memory management divides cache into blocks/pages, reducing fragmentation and enabling efficient batching.

## Latency and throughput

Useful serving measurements include:

- **Time to first token (TTFT):** request arrival to first generated token
- **Inter-token latency (ITL):** delay between generated tokens
- **Tokens per second:** generation rate
- **Request throughput:** completed requests per unit time
- **Goodput:** requests satisfying a service-level objective
- **Concurrency:** simultaneous active requests

A configuration optimized for single-user latency may differ from one optimized for aggregate throughput.

## Batching and scheduling

Static batching waits for a fixed batch. Continuous or iteration-level batching can insert and remove requests between decode iterations. vLLM uses scheduling and memory management to improve accelerator utilization across requests.

Those are the concepts directly relevant to the first run. Parallelism, orchestration, distributed serving, and platform architecture are intentionally deferred.
