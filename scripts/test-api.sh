#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ -f "$repo_root/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$repo_root/.env"
  set +a
fi

port=8000
model="${SERVED_MODEL_NAME:-${MODEL_ID:-Qwen/Qwen2.5-0.5B-Instruct}}"

curl -fsS "http://127.0.0.1:${port}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n \
    --arg model "$model" \
    --arg prompt "${PROMPT:-In one short sentence, explain what vLLM does.}" \
    '{model: $model, messages: [{role: "user", content: $prompt}], max_tokens: 64, temperature: 0}')" \
  | jq .
