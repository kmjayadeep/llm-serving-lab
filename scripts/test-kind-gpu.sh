#!/usr/bin/env bash
set -euo pipefail

context="kind-llm-serving-gpu-lab"
namespace="llm-serving-gpu-lab"
url="http://localhost:11434"
model="qwen2.5:0.5b"

command -v kubectl >/dev/null || { echo "missing required command: kubectl" >&2; exit 1; }
command -v curl >/dev/null || { echo "missing required command: curl" >&2; exit 1; }

printf 'Sending one non-streaming inference request to %s...\n' "$model"
response="$(curl --fail --silent --show-error --max-time 180 \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"$model\",\"prompt\":\"Reply briefly: Kubernetes GPU inference works\",\"stream\":false,\"options\":{\"temperature\":0,\"num_predict\":32}}" \
  "$url/api/generate")"

RESPONSE="$response" python3 - <<'PY'
import json
import os
payload = json.loads(os.environ["RESPONSE"])
text = payload.get("response", "").strip()
if not text:
    raise SystemExit("inference response was empty")
print("Response:", text)
print("Evaluation tokens:", payload.get("eval_count"))
print("Evaluation duration (ns):", payload.get("eval_duration"))
PY

pod="$(kubectl --context "$context" -n "$namespace" get pod -l app=ollama -o jsonpath='{.items[0].metadata.name}')"
printf '\nOllama processor placement:\n'
processor="$(kubectl --context "$context" -n "$namespace" exec "$pod" -- ollama ps)"
printf '%s\n' "$processor"
grep -qi 'GPU' <<<"$processor" || {
  echo "Inference completed, but Ollama did not report GPU placement" >&2
  echo "Inspect logs: kubectl --context $context -n $namespace logs deployment/ollama" >&2
  exit 1
}

gpu_line="$(kubectl --context "$context" -n "$namespace" logs deployment/ollama | grep 'inference compute' | tail -1)"
printf '\nDetected accelerator:\n%s\n' "$gpu_line"
grep -q 'AMD Radeon RX 7900 GRE' <<<"$gpu_line" || {
  echo "Expected the RX 7900 GRE, but Ollama selected another accelerator" >&2
  exit 1
}

printf '\nGPU inference test passed.\n'
