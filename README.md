# LLM Serving Lab

A small, incremental learning repository for experimenting with LLM inference and serving.

The repository currently documents only the first completed experiment: running a small model with vLLM and ROCm on an AMD Radeon RX 7900 GRE.

## What has been tested

- AMD Radeon RX 7900 GRE (`gfx1100`) with 16 GiB VRAM
- NixOS host with the `amdgpu` kernel driver
- GPU access from a Docker container through `/dev/kfd` and `/dev/dri`
- ROCm 7.2.1 and ROCm-enabled PyTorch
- vLLM serving `Qwen/Qwen2.5-0.5B-Instruct`
- OpenAI-compatible chat-completions API on port 8000
- A dependency-free browser chat interface with streaming responses
- Explicit selection of the discrete GPU instead of the integrated AMD GPU
- Complete cleanup after the experiment

The exact observations are in [`docs/01-rx7900gre-first-vllm-run.md`](docs/01-rx7900gre-first-vllm-run.md).

## Repository contents

```text
.
├── artifacts/                  # Sanitized output from the completed experiment
├── docs/
│   ├── 01-rx7900gre-first-vllm-run.md
│   ├── 02-inference-fundamentals.md
│   ├── 03-vllm-and-rocm.md
│   ├── 04-containers-and-storage.md
│   ├── 05-lightweight-chat-ui.md
│   └── references.md
├── guides/
│   └── local-rocm-vllm.md      # Procedure for repeating the experiment
├── scripts/                    # Host checks, API tests, UI server, and cleanup
├── ui/                         # Dependency-free local chat page
├── compose.yaml                # vLLM service
└── .env.example                # Local experiment settings
```

The Compose workflow runs vLLM; a small host-side HTTP server serves the static chat page.

## Read slowly

Use this order:

1. [`docs/01-rx7900gre-first-vllm-run.md`](docs/01-rx7900gre-first-vllm-run.md) — what was done
2. [`docs/02-inference-fundamentals.md`](docs/02-inference-fundamentals.md) — only the concepts seen in that run
3. [`docs/03-vllm-and-rocm.md`](docs/03-vllm-and-rocm.md) — how the AMD software stack fits together
4. [`docs/04-containers-and-storage.md`](docs/04-containers-and-storage.md) — what Docker provided
5. [`docs/05-lightweight-chat-ui.md`](docs/05-lightweight-chat-ui.md) — how the chat interface connects
6. [`guides/local-rocm-vllm.md`](guides/local-rocm-vllm.md) — how to repeat it
7. [`docs/references.md`](docs/references.md) — primary sources

There is no need to understand all of these files at once. Start with the session note and ask one question at a time.

## Repeat the local experiment

Check the host:

```bash
./scripts/check-amd-gpu.sh
```

Prepare local configuration:

```bash
cp .env.example .env
$EDITOR .env
```

Pull and verify the ROCm image:

```bash
docker compose pull
./scripts/verify-rocm-container.sh
```

Start vLLM and test the API:

```bash
docker compose up -d
./scripts/wait-for-server.sh
./scripts/test-api.sh
```

In another terminal, start the lightweight UI:

```bash
./scripts/serve-ui.sh
```

Open [http://localhost:3001](http://localhost:3001).

View logs:

```bash
docker compose logs -f vllm
```

Stop it:

```bash
docker compose down
```

Use [`scripts/cleanup.sh`](scripts/cleanup.sh) for targeted cleanup of this lab's resources.

## Next steps — not implemented yet

These are intentionally only TODOs. They should be added one at a time after the current local setup is understood and reproduced.

- [x] Re-run and document the Compose workflow
- [x] Try Open WebUI and identify which features are unnecessary for this lab
- [x] Replace it with a dependency-free browser chat interface
- [x] Measure one request's latency and tokens per second
- [ ] Compare the 0.5B model with one slightly larger model
- [ ] Learn basic concurrent-request behavior
- [ ] Add a minimal benchmark script after the measurements are understood
- [ ] Learn what Kubernetes contributes to model serving
- [ ] Try one minimal Kubernetes vLLM deployment
- [ ] Learn the purpose of llm-d
- [ ] Plan a dedicated GPU homelab node

Kubernetes, llm-d, distributed serving, autoscaling, and production architecture are outside the current scope.

## Safety

- Do not commit Hugging Face tokens, model weights, kubeconfigs, or private prompts.
- Check a model's license before downloading or distributing it.
- Do not expose an unauthenticated vLLM endpoint to an untrusted network.
