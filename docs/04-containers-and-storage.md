# Containers and storage

## GPU passthrough

```yaml
devices:
  - /dev/kfd:/dev/kfd
  - /dev/dri:/dev/dri
group_add: [video]
ipc: host
```

- `/dev/kfd`: AMD compute interface.
- `/dev/dri`: render devices.
- Host IPC avoids a small container shared-memory limit.
- The container shares the host kernel; it does not virtualize the GPU.

## Network and cache

This lab uses host networking:

```text
browser :3001 -> NGINX -> vLLM :8000
```

The host Hugging Face cache is mounted at `/root/.cache/huggingface`, so models
survive container replacement. Watch ownership and disk usage.

## Useful checks

```bash
docker compose ps
docker compose logs -f vllm ui
docker system df
df -h /
docker compose down
```

Prefer targeted cleanup over `docker system prune` when Docker hosts other
projects.
