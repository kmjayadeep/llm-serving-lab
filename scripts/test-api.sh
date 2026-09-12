#!/usr/bin/env bash
set -euo pipefail

port="${PORT:-8000}"
model="${SERVED_MODEL_NAME:-${MODEL_ID:-Qwen/Qwen2.5-0.5B-Instruct}}"

curl -fsS "http://127.0.0.1:${port}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n \
    --arg model "$model" \
    --arg prompt "${PROMPT:-In one short sentence, explain what vLLM does.}" \
    '{model: $model, messages: [{role: "user", content: $prompt}], max_tokens: 64, temperature: 0}')" \
  | jq .
