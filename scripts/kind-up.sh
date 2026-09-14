#!/usr/bin/env bash
set -euo pipefail

cluster="llm-serving-lab"
context="kind-${cluster}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
original_context="$(kubectl config current-context 2>/dev/null || true)"
restore_context() {
  if [[ -n "$original_context" ]]; then
    kubectl config use-context "$original_context" >/dev/null
  fi
}
trap restore_context EXIT

for command in docker kind kubectl curl; do
  command -v "$command" >/dev/null || { echo "missing required command: $command" >&2; exit 1; }
done

docker info >/dev/null 2>&1 || { echo "Docker is not running" >&2; exit 1; }

if ! kind get clusters | grep -qx "$cluster"; then
  kind create cluster --config "$root/kind/cluster.yaml"
else
  echo "kind cluster '$cluster' already exists"
fi

kubectl --context "$context" apply -f "$root/k8s/phase2.yaml"
generation="$(kubectl --context "$context" -n llm-serving-lab get deployment/inference-test -o jsonpath='{.metadata.generation}')"
for _ in $(seq 1 60); do
  observed="$(kubectl --context "$context" -n llm-serving-lab get deployment/inference-test -o jsonpath='{.status.observedGeneration}')"
  [[ "$observed" == "$generation" ]] && break
  sleep 1
done
[[ "$observed" == "$generation" ]] || { echo "Deployment generation $generation was not observed" >&2; exit 1; }
kubectl --context "$context" -n llm-serving-lab rollout status deployment/inference-test --timeout=180s

echo
echo "Workload is ready:"
kubectl --context "$context" -n llm-serving-lab get deployment,pods,service,pvc
echo
echo "Service response at http://localhost:8080:"
curl --fail --silent --show-error http://localhost:8080/
