#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

if [[ -f .env ]]; then
  # Load only simple KEY=VALUE settings from this repository's local env file.
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

image="${VLLM_IMAGE:-rocm/vllm-dev:rocm7.2.1_navi_ubuntu24.04_py3.12_pytorch_2.9_vllm_0.16.0}"
ui_image="${UI_IMAGE:-vllm-lab-ui:local}"
model="${MODEL_ID:-Qwen/Qwen2.5-0.5B-Instruct}"
cache_name="models--${model//\//--}"

docker compose down --remove-orphans

for container_image in "$image" "$ui_image"; do
  echo "Removing image: $container_image"
  docker image rm "$container_image" 2>/dev/null || true
done

read -r -p "Remove cached model $model as well? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  # A container may have created root-owned cache files. Use a small container
  # rather than changing ownership of the entire Hugging Face cache.
  docker run --rm \
    -v "${HOME}/.cache/huggingface:/cache" \
    alpine:3.21 rm -rf "/cache/hub/${cache_name}"
  docker image rm alpine:3.21 2>/dev/null || true
fi

echo
printf 'Disk usage after targeted cleanup:\n'
df -h /
docker system df
