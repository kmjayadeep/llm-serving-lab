#!/usr/bin/env bash
set -euo pipefail

cluster="llm-serving-gpu-lab"
context="kind-${cluster}"
namespace="$cluster"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for command in docker kind kubectl curl; do
  command -v "$command" >/dev/null || { echo "missing required command: $command" >&2; exit 1; }
done
[[ -e /dev/kfd && -d /dev/dri ]] || { echo "AMD GPU devices /dev/kfd and /dev/dri are required" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker is not running" >&2; exit 1; }

original_context="$(kubectl config current-context 2>/dev/null || true)"
restore_context() {
  [[ -z "$original_context" ]] || kubectl config use-context "$original_context" >/dev/null
}
trap restore_context EXIT

if ! kind get clusters | grep -qx "$cluster"; then
  kind create cluster --config "$root/kind/gpu-cluster.yaml"
else
  echo "kind cluster '$cluster' already exists"
fi

echo "Checking GPU device passthrough into the kind node..."
docker exec "${cluster}-control-plane" test -e /dev/kfd
docker exec "${cluster}-control-plane" test -d /dev/dri

kubectl --context "$context" apply -f "$root/k8s/amd-device-plugin.yaml"
kubectl --context "$context" -n kube-system rollout status daemonset/amdgpu-device-plugin --timeout=180s

for _ in $(seq 1 60); do
  gpu_count="$(kubectl --context "$context" get node -o jsonpath='{.items[0].status.allocatable.amd\.com/gpu}' 2>/dev/null || true)"
  [[ "$gpu_count" =~ ^[1-9][0-9]*$ ]] && break
  sleep 2
done
[[ "$gpu_count" =~ ^[1-9][0-9]*$ ]] || {
  echo "AMD device plugin did not advertise any amd.com/gpu resources" >&2
  kubectl --context "$context" -n kube-system logs daemonset/amdgpu-device-plugin >&2 || true
  exit 1
}
echo "Kubernetes allocatable amd.com/gpu: $gpu_count (discrete GPU plus integrated GPU)"

kubectl --context "$context" apply -f "$root/k8s/gpu-inference.yaml"
kubectl --context "$context" -n "$namespace" rollout status deployment/ollama --timeout=900s

# Jobs cannot be updated after completion; recreate this idempotent model pull.
kubectl --context "$context" -n "$namespace" delete job/pull-qwen-model --ignore-not-found >/dev/null
kubectl --context "$context" apply -f "$root/k8s/gpu-model-pull.yaml"
kubectl --context "$context" -n "$namespace" wait --for=condition=complete job/pull-qwen-model --timeout=600s

kubectl --context "$context" -n "$namespace" get pod,service,pvc,job
echo
echo "Ollama is ready at http://localhost:11434"
