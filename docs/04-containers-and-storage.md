# Containers and storage

## AMD GPU access

The ROCm container needs:

```yaml
devices:
  - /dev/kfd:/dev/kfd
  - /dev/dri:/dev/dri
group_add:
  - video
ipc: host
```

- `/dev/kfd` provides the AMD compute interface.
- `/dev/dri` exposes render devices.
- Device permissions depend on host groups and udev rules.
- Host IPC avoids small default shared-memory limits.

Containers use the host kernel and GPU driver; they do not virtualize the GPU.

## Network

Both lab containers use host networking:

- vLLM binds to `127.0.0.1:8000`.
- NGINX binds to `127.0.0.1:3001` and proxies API traffic to vLLM.

## Model cache

The Hugging Face cache is mounted from the host:

```text
$HOME/.cache/huggingface → /root/.cache/huggingface
```

Model downloads survive container replacement. The container may create root-owned cache files, so the cleanup script removes a selected model through a temporary container.

## Inspect and clean up

```bash
df -h /
docker system df
docker compose down
```

Use [`scripts/cleanup.sh`](../scripts/cleanup.sh) to remove this lab's containers, images, and optionally the selected model cache.

Avoid broad cleanup commands when unrelated Docker projects exist. Remove known resources first.
