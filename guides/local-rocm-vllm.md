# Guide: local vLLM on an AMD GPU

This reproduces the successful RX 7900 GRE experiment using Docker Compose.

## Prerequisites

- Linux host with `amdgpu`
- Supported AMD GPU/ROCm combination
- `/dev/kfd` and `/dev/dri`
- Docker with Compose v2
- At least 70–100 GiB free for the tested development image
- `curl` and `jq`

## Procedure

```bash
./scripts/check-amd-gpu.sh
cp .env.example .env
```

Before selecting `HIP_VISIBLE_DEVICES`, pull the image and inspect devices:

```bash
set -a; source .env; set +a
./scripts/verify-rocm-container.sh
```

The image pull itself is large. After identifying the discrete GPU index, edit `.env`, then start:

```bash
docker compose up -d
./scripts/wait-for-server.sh
./scripts/test-api.sh
```

Useful checks:

```bash
curl -fsS http://localhost:8000/health
curl -fsS http://localhost:8000/v1/models | jq .
docker compose logs -f vllm
```

## Try a custom prompt

```bash
PROMPT='Explain KV caching in two sentences.' ./scripts/test-api.sh
```

## Change models

Edit `.env`:

```dotenv
MODEL_ID=Qwen/Qwen2.5-1.5B-Instruct
SERVED_MODEL_NAME=qwen-1.5b
```

Then recreate the container:

```bash
docker compose up -d --force-recreate
```

Check model VRAM requirements and license first. Larger models and contexts leave less capacity for KV cache and concurrent requests.

## Test optimized execution

The baseline uses `--enforce-eager`. To test graph/compiled execution, remove that line from `compose.yaml`, recreate the container, and compare the same prompt/concurrency workload. Restore eager mode if ROCm/Triton compilation fails.

## Troubleshooting

### No `/dev/kfd`

The host driver/ROCm-compatible kernel path is not ready. Docker cannot manufacture this device.

### Two AMD devices appear

An APU and discrete GPU may both be visible. Use `HIP_VISIBLE_DEVICES` after verifying device order.

### Permission denied

Check host device ownership and membership in `video`/`render`. Log out and back in after changing group membership.

### Server exits during startup

```bash
docker compose ps -a
docker compose logs --tail=200 vllm
```

Look for unsupported architecture, kernel compilation, out-of-memory, model access, and disk errors.

### No space left on device

```bash
df -h /
docker system df -v
du -sh ~/.cache/huggingface
```

Do not immediately run a global prune on a machine with other Docker projects. Remove known resources or use `scripts/cleanup.sh`.

## Stop and clean up

Preserve image/cache:

```bash
docker compose down
```

Targeted full lab cleanup:

```bash
./scripts/cleanup.sh
```
