#!/usr/bin/env bash
set -euo pipefail

cluster=llm-serving-lab
context=kind-$cluster
root=$(cd "$(dirname "$0")/.." && pwd)
current=$(kubectl config current-context 2>/dev/null || true)
trap '[[ -z "$current" ]] || kubectl config use-context "$current" >/dev/null' EXIT

kind get clusters | grep -qx "$cluster" || \
  kind create cluster --config "$root/kind/cluster.yaml"

kubectl --context "$context" apply -f "$root/k8s/phase2.yaml"
kubectl --context "$context" -n "$cluster" rollout status \
  deployment/inference-test --timeout=3m
kubectl --context "$context" -n "$cluster" get pods,service,pvc
curl -fsS http://localhost:8080/
