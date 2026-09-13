# Run vLLM locally with ROCm

## Requirements

- Linux with a compatible AMD GPU and `amdgpu`
- `/dev/kfd` and `/dev/dri`
- Docker Compose v2
- `curl` and `jq`

## 1. Configure

```bash
./scripts/check-amd-gpu.sh
cp .env.example .env
$EDITOR .env
```

Verify GPU ordering before choosing `HIP_VISIBLE_DEVICES`:

```bash
set -a; source .env; set +a
./scripts/verify-rocm-container.sh
```

## 2. Start

```bash
docker compose up -d --build
./scripts/wait-for-server.sh
./scripts/test-api.sh
```

Open the UI at [http://localhost:3001](http://localhost:3001).

## 3. Inspect

```bash
docker compose ps
docker compose logs -f vllm ui
curl -fsS http://localhost:8000/health
curl -fsS http://localhost:3001/v1/models | jq
curl -fsS http://localhost:3001/metrics | less
```

## 4. Stop

Preserve images and model cache:

```bash
docker compose down
```

Remove lab images and optionally the selected model cache:

```bash
./scripts/cleanup.sh
```

## Troubleshooting

### GPU is unavailable

Confirm `amdgpu`, `/dev/kfd`, render devices, and `video`/`render` group membership. Re-run `scripts/verify-rocm-container.sh`.

### Server exits

```bash
docker compose ps -a
docker compose logs --tail=200 vllm
```

Check for unsupported GPU architecture, out-of-memory errors, model access errors, and incompatible kernels.

### UI is unavailable

```bash
docker compose logs --tail=100 ui
curl -v http://127.0.0.1:3001/health
```
