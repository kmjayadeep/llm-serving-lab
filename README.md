# LLM Serving Lab

A hands-on lab for learning local and clustered LLM inference: **vLLM**, **ROCm**, containers, Kubernetes, and **llm-d**. The long-term goal is to move experiments from a desktop AMD GPU to a dedicated GPU homelab.

> This is a learning repository, not a production-ready serving platform. Images, flags, and hardware support change quickly; pin versions and revalidate before each experiment.

## Current status

The first experiment successfully served `Qwen/Qwen2.5-0.5B-Instruct` with vLLM on an AMD Radeon RX 7900 GRE:

- AMD Navi 31 / `gfx1100`, 16 GiB VRAM
- NixOS host using the `amdgpu` kernel driver
- ROCm 7.2.1 and vLLM 0.16 development image
- OpenAI-compatible endpoint on `http://localhost:8000`
- FP16, 2,048-token context, eager execution

See [the first session notes](docs/01-rx7900gre-first-vllm-run.md) and its [captured artifacts](artifacts/2026-09-rx7900gre/).

## Repository map

```text
.
├── artifacts/                  # Sanitized outputs and observations from experiments
├── docs/                       # Concept notes and architecture learning
├── guides/                     # Repeatable procedures
├── kubernetes/base/            # Educational single-node Kubernetes baseline
├── scripts/                    # GPU checks, launch, API test, cleanup
├── compose.yaml                # Local ROCm/vLLM experiment
└── .env.example                # Tunable local settings
```

## Quick start: AMD ROCm

### 1. Check the host

```bash
./scripts/check-amd-gpu.sh
```

You need an AMD GPU supported by the selected ROCm image, the `amdgpu` driver, `/dev/kfd`, `/dev/dri`, and Docker Compose.

### 2. Review storage first

The tested development image is very large. Keep at least **70–100 GiB free** before pulling it:

```bash
df -h /
docker system df
```

### 3. Configure and launch

```bash
cp .env.example .env
# Review .env, particularly HIP_VISIBLE_DEVICES and the model.
docker compose up -d
./scripts/wait-for-server.sh
./scripts/test-api.sh
```

Follow logs:

```bash
docker compose logs -f vllm
```

Stop while preserving the image and model cache:

```bash
docker compose down
```

Remove this lab's container, image, and selected model cache:

```bash
./scripts/cleanup.sh
```

The cleanup script is deliberately targeted; it does not run a system-wide `docker system prune`.

## Learning path

1. [Inference fundamentals](docs/02-inference-fundamentals.md)
2. [vLLM and ROCm](docs/03-vllm-and-rocm.md)
3. [Container storage and GPU access](docs/04-containers-and-storage.md)
4. [Kubernetes model serving](docs/05-kubernetes-serving.md)
5. [llm-d concepts](docs/06-llm-d.md)
6. [Homelab roadmap](docs/07-homelab-roadmap.md)
7. [References](docs/references.md)

## Planned experiments

- Compare eager mode with compiled/graph execution on `gfx1100`
- Benchmark 0.5B, 1.5B, and 3B models
- Measure time-to-first-token and inter-token latency
- Compare FP16 with supported quantization formats
- Build or locate a smaller ROCm runtime image
- Deploy a single vLLM pod with the AMD Kubernetes device plugin
- Add observability with Prometheus and Grafana
- Explore inference-aware routing and disaggregated serving with llm-d
- Move repeatable workloads to a dedicated homelab GPU node

## Safety and expectations

- Do not commit Hugging Face tokens, kubeconfigs, model weights, or private prompts.
- Verify model licenses before downloading or redistributing weights.
- Treat manifests under `kubernetes/` as educational baselines.
- Never expose an unauthenticated vLLM endpoint directly to the internet.
