# Containers, GPU access, and storage

## Containers do not virtualize the GPU

A GPU container shares the host kernel. Device nodes are passed into the container, while ROCm user-space libraries live in the image.

For the tested AMD setup:

```yaml
devices:
  - /dev/kfd:/dev/kfd
  - /dev/dri:/dev/dri
group_add:
  - video
ipc: host
```

`/dev/kfd` provides the Kernel Fusion Driver compute interface. `/dev/dri` exposes render nodes. Group and udev permissions determine whether a non-root host user can access them.

`ipc: host` avoids a small default shared-memory allocation that can constrain ML frameworks. Understand the isolation trade-off before using it in multi-tenant environments.

## Host networking

The local Compose setup uses `network_mode: host`, so vLLM's port is directly bound on the host. This is convenient for a trusted workstation but reduces network isolation.

Never expose an unauthenticated model server to an untrusted network. Add a gateway or proxy that handles TLS, authentication, request limits, and authorization.

## Image layers and working space

Registry layers are compressed for transfer, then extracted into content and snapshot storage. During a pull, disk may temporarily hold compressed blobs and extracted data simultaneously. Containers add writable overlay layers, and build caches consume additional space.

Inspect storage with:

```bash
df -h /
docker system df
docker system df -v
```

A large AI image may need far more temporary headroom than its displayed download size.

## Model cache

The Compose file mounts:

```text
$HOME/.cache/huggingface → /root/.cache/huggingface
```

This prevents repeated model downloads when containers are replaced. It also means:

- Model files persist independently of the container.
- Gated models may use a token from the environment.
- Cache files can be created as root.
- Model weights can consume substantial host storage.

Do not commit caches or model weights to Git.

## Targeted cleanup

Prefer removing known lab resources:

```bash
docker compose down
docker image rm IMAGE_NAME
rm only the intended model cache
```

Use `scripts/cleanup.sh` for this repository.

Commands such as the following are broad and potentially disruptive:

```bash
docker system prune -af
docker volume prune
```

They can delete unrelated inactive images, build cache, and—depending on flags—volumes. Inspect first and use them only when that scope is intentional.

## Long-term storage options

For a homelab, consider:

- A dedicated SSD/filesystem for container data
- A dedicated model cache volume
- Registry mirrors or a local registry
- Read-only model volumes shared by replicas
- Object storage or artifact repositories for model distribution
- Explicit retention policies for benchmark outputs and caches

Docker's `data-root` can be relocated, but do so through daemon configuration and a deliberate migration rather than moving live overlay directories manually.
