# LLM Serving Lab

Incremental experiments with local LLM serving, routing, and orchestration.

## Current setup

Tested on an AMD Radeon RX 7900 GRE (`gfx1100`, 16 GiB VRAM):

- NixOS with the `amdgpu` driver
- ROCm 7.2.1 and ROCm-enabled PyTorch
- vLLM serving `Qwen/Qwen2.5-0.5B-Instruct`
- OpenAI-compatible API on `127.0.0.1:8000`
- Lightweight NGINX chat UI/proxy on `127.0.0.1:3001`
- vLLM health, performance, and cache metrics in the UI

```text
Browser → NGINX :3001 → vLLM :8000 → ROCm → GPU
```

## Repository

```text
.
├── artifacts/                  # Results from completed experiments
├── docs/                       # Short concept and experiment notes
├── guides/local-rocm-vllm.md  # Reproduction guide
├── kind/                       # Local Kubernetes cluster definition
├── k8s/                        # Kubernetes workload manifests
├── scripts/                    # Checks, API tests, and lifecycle helpers
├── ui/                         # Static chat UI and NGINX config
├── compose.yaml
└── Dockerfile.ui
```

Start with:

1. [First vLLM run](docs/01-rx7900gre-first-vllm-run.md)
2. [Inference fundamentals](docs/02-inference-fundamentals.md)
3. [vLLM and ROCm](docs/03-vllm-and-rocm.md)
4. [Containers and storage](docs/04-containers-and-storage.md)
5. [Lightweight chat UI](docs/05-lightweight-chat-ui.md)
6. [Local reproduction guide](guides/local-rocm-vllm.md)
7. [References](docs/references.md)
8. [Local vLLM benchmark](bench/README.md)
9. [Kubernetes with kind](docs/06-kubernetes-with-kind.md)
10. [GPU inference with kind](docs/07-gpu-inference-with-kind.md)

## Run

```bash
cp .env.example .env
./scripts/check-amd-gpu.sh
docker compose up -d --build
./scripts/wait-for-server.sh
./scripts/test-api.sh
```

Open [http://localhost:3001](http://localhost:3001).

Useful commands:

```bash
docker compose ps
docker compose logs -f vllm ui
docker compose down
```

Targeted cleanup:

```bash
./scripts/cleanup.sh
```

## Kubernetes Phase 2

Run the CPU-only Kubernetes experiment without affecting the current kubectl
context:

```bash
make kind-up
make kind-test
make kind-down
```

The kind workload exercises a Deployment, Service, ConfigMap, persistent
storage, all three probe types, Pod replacement, failed startup, and a rolling
update. See [Kubernetes with kind](docs/06-kubernetes-with-kind.md).

Run the separate AMD GPU experiment:

```bash
make kind-gpu-up
make kind-gpu-test
make kind-gpu-down
```

This passes the host GPU into kind, installs the AMD device plugin, and runs
`qwen2.5:0.5b` with Ollama on the RX 7900 GRE. See
[GPU inference with kind](docs/07-gpu-inference-with-kind.md).

## Observed baseline

Five requests with 128 input and 128 output tokens at concurrency one:

| Metric | Result |
|---|---:|
| Output throughput | 103.22 tokens/s |
| Mean time to first token | 24.93 ms |
| Mean time per output token | 9.57 ms |
| Mean end-to-end latency | 1.24 s |

See [server observations](artifacts/2026-09-rx7900gre/server-observations.md).

The expanded Phase 1 baseline compares the 0.5B and 3B models from concurrency
1 through 16. See the [benchmark report](artifacts/2026-09-rx7900gre/phase1-baseline.md)
or open the [interactive visualization](artifacts/2026-09-rx7900gre/phase1-baseline.html).

## Next steps

- [x] Validate the Kubernetes deployment model locally with kind
- [x] Run a lightweight GPU inference workload inside kind
- [ ] Put llm-d Envoy and EPP in front of the existing vLLM worker
- [ ] Explore file-based endpoint discovery without Kubernetes
- [ ] Run more than one worker and inspect routing decisions
- [ ] Learn Kubernetes Gateway API inference primitives
- [ ] Evaluate KServe `LLMInferenceService` for model declarations
- [ ] Plan a dedicated GPU node
