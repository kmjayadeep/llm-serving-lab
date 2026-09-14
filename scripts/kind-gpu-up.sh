#!/usr/bin/env bash
set -euo pipefail

cluster=llm-serving-gpu-lab
context=kind-$cluster
root=$(cd "$(dirname "$0")/.." && pwd)
[[ -e /dev/kfd && -d /dev/dri ]] || { echo 'AMD GPU devices not found' >&2; exit 1; }
current=$(kubectl config current-context 2>/dev/null || true)
trap '[[ -z "$current" ]] || kubectl config use-context "$current" >/dev/null' EXIT

kind get clusters | grep -qx "$cluster" || \
  kind create cluster --config "$root/kind/gpu-cluster.yaml"

docker exec "$cluster-control-plane" test -e /dev/kfd
kubectl --context "$context" apply -f "$root/k8s/amd-device-plugin.yaml"
kubectl --context "$context" -n kube-system rollout status \
  daemonset/amdgpu-device-plugin --timeout=3m

for _ in {1..60}; do
  gpus=$(kubectl --context "$context" get node \
    -o jsonpath='{.items[0].status.allocatable.amd\.com/gpu}' 2>/dev/null || true)
  [[ "$gpus" =~ ^[1-9] ]] && break
  sleep 2
done
[[ "$gpus" =~ ^[1-9] ]] || { echo 'No amd.com/gpu resource' >&2; exit 1; }
echo "Allocatable AMD GPUs: $gpus"

kubectl --context "$context" apply -f "$root/k8s/gpu-inference.yaml"
kubectl --context "$context" -n "$cluster" rollout status deployment/ollama --timeout=15m
kubectl --context "$context" -n "$cluster" delete job/pull-qwen-model --ignore-not-found
kubectl --context "$context" apply -f "$root/k8s/gpu-model-pull.yaml"
kubectl --context "$context" -n "$cluster" wait --for=condition=complete \
  job/pull-qwen-model --timeout=10m
