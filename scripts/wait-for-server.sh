#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

port=8000
timeout="${TIMEOUT_SECONDS:-300}"
start=$SECONDS

printf 'Waiting for vLLM at http://127.0.0.1:%s/health ' "$port"
until curl -fsS "http://127.0.0.1:${port}/health" >/dev/null 2>&1; do
  if (( SECONDS - start >= timeout )); then
    echo
    echo "Timed out after ${timeout}s" >&2
    docker compose logs --tail=100 vllm >&2 || true
    exit 1
  fi
  printf '.'
  sleep 5
done
printf ' ready\n'
