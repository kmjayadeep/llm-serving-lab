# llm-d concepts

## What llm-d is

llm-d is a Kubernetes-oriented distributed inference serving project. It builds on vLLM and Kubernetes ecosystem components to improve the operation and performance of large-scale inference deployments.

It should not be confused with:

- `llmd`, an arbitrary local daemon name
- LLVM's `lld` linker
- vLLM itself

The project name is written **llm-d**.

## Why a higher-level system is needed

A standalone vLLM instance can efficiently serve a model on one or more accelerators. A fleet introduces additional questions:

- Which replica should receive a request?
- Which replica has useful prefix-cache state?
- How should long prompts and decode-heavy requests be balanced?
- Should prefill and decode run on different workers?
- How are model artifacts delivered to nodes?
- How are heterogeneous accelerators represented?
- How should the deployment scale while preserving latency objectives?

llm-d addresses this broader distributed-serving problem rather than replacing the underlying inference engine.

## Core ideas to learn

The exact components evolve, but the important architectural ideas include:

### Inference-aware routing

A generic load balancer sees requests and connections. An inference-aware router can consider signals such as queue depth, cache affinity, expected work, and backend health.

### Prefix-cache-aware routing

Requests sharing a long prefix may benefit from reaching a worker that already has reusable cached state. Better cache locality can reduce repeated prefill computation.

### Prefill/decode disaggregation

Prefill and decode have different performance characteristics. A distributed design may assign them to different worker pools and transfer required state between them. This can improve utilization for some workloads but adds networking, state transfer, and failure complexity.

### Distributed scheduling

Scheduling extends beyond “a pod requests a GPU.” The system may need to consider accelerator topology, model placement, parallelism strategy, memory capacity, and service objectives.

### Model artifacts

Large weights must reach workers reliably and quickly. Artifact caching and distribution become first-class operational concerns because naive downloads produce slow starts and external bottlenecks.

## Relationship to Kubernetes APIs

llm-d uses cloud-native interfaces and integrates with Kubernetes/Gateway ecosystem concepts rather than requiring every concern to live inside vLLM. Consult the pinned llm-d release documentation before installation because APIs, charts, and supported configurations are actively evolving.

## Suggested learning order

Do not begin with llm-d on the workstation. Build understanding incrementally:

1. One vLLM process, one GPU
2. Measure one request and concurrent requests
3. One vLLM Kubernetes pod
4. Multiple replicas and ordinary routing
5. Metrics and load generation
6. Prefix caching and routing behavior
7. llm-d quickstart on a test cluster
8. Disaggregated serving only after understanding baseline behavior

## Hardware caution

llm-d's goal is modern accelerator serving, but a project's broad architecture and a specific Radeon GPU's tested support are separate questions. Confirm the chosen llm-d release, vLLM image, kernels, and device-plugin support for the homelab accelerator.
