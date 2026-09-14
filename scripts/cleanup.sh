#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
[[ ! -f .env ]] || { set -a; source .env; set +a; }

image="${VLLM_IMAGE:-rocm/vllm-dev:rocm7.2.1_navi_ubuntu24.04_py3.12_pytorch_2.9_vllm_0.16.0}"
ui_image="${UI_IMAGE:-vllm-lab-ui:local}"
model="${MODEL_ID:-Qwen/Qwen2.5-0.5B-Instruct}"
cache="models--${model//\//--}"

docker compose down --remove-orphans
docker image rm "$image" "$ui_image" 2>/dev/null || true

read -r -p "Remove cached $model? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  docker run --rm -v "$HOME/.cache/huggingface:/cache" alpine:3.21 \
    rm -rf "/cache/hub/$cache"
  docker image rm alpine:3.21 2>/dev/null || true
fi

df -h /
docker system df
