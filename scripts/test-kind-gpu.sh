#!/usr/bin/env bash
set -euo pipefail

context=kind-llm-serving-gpu-lab
namespace=llm-serving-gpu-lab
response=$(curl -fsS --max-time 3m http://localhost:11434/api/generate \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen2.5:0.5b","prompt":"Explain readiness probes briefly.","stream":false,"options":{"temperature":0,"num_predict":32}}')

RESPONSE="$response" python3 - <<'PY'
import json, os
result = json.loads(os.environ["RESPONSE"])
assert result.get("response"), "empty inference response"
print(result["response"].strip())
print(f'{result.get("eval_count")} tokens in {result.get("eval_duration")} ns')
PY

pod=$(kubectl --context "$context" -n "$namespace" get pod -l app=ollama \
  -o jsonpath='{.items[0].metadata.name}')
placement=$(kubectl --context "$context" -n "$namespace" exec "$pod" -- ollama ps)
discovery=$(kubectl --context "$context" -n "$namespace" logs "$pod" |
  grep 'inference compute' | tail -1)

printf '\n%s\n%s\n' "$placement" "$discovery"
grep -qi 'GPU' <<<"$placement"
grep -q 'AMD Radeon RX 7900 GRE' <<<"$discovery"
