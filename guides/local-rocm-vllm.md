# Run vLLM locally with ROCm

Requirements: Linux, `amdgpu`, `/dev/kfd`, `/dev/dri`, Docker Compose, curl,
and jq.

## Reproduce

```bash
cp .env.example .env
./scripts/check-amd-gpu.sh
./scripts/verify-rocm-container.sh

docker compose up -d --build
./scripts/wait-for-server.sh
./scripts/test-api.sh
```

Open <http://localhost:3001>.

The equivalent checks without helper scripts are:

```bash
ls -l /dev/kfd /dev/dri/renderD*
docker compose ps
docker compose logs --tail=100 vllm
curl -fsS http://localhost:8000/health
curl -fsS http://localhost:3001/v1/models | jq
```

## Configuration to verify

```text
VLLM_IMAGE=<pinned ROCm image>
MODEL_ID=Qwen/Qwen2.5-0.5B-Instruct
HIP_VISIBLE_DEVICES=0   # only after checking device order
DTYPE=float16
MAX_MODEL_LEN=2048
GPU_MEMORY_UTILIZATION=0.75
```

## If startup fails

1. Confirm `amdgpu`, `/dev/kfd`, and `/dev/dri/renderD*`.
2. Confirm PyTorch in the image sees the intended GPU.
3. Check disk space, VRAM, model access, and container logs.
4. Keep the known image/model combination before changing one variable at a
   time.

```bash
docker compose down             # keep image and model cache
./scripts/cleanup.sh            # targeted image/cache cleanup
```
