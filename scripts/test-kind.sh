#!/usr/bin/env bash
set -euo pipefail

context="kind-llm-serving-lab"
namespace="llm-serving-lab"
deployment="inference-test"
url="http://localhost:8080"

k() { kubectl --context "$context" -n "$namespace" "$@"; }
section() { printf '\n==> %s\n' "$1"; }
service_request() { curl --fail --silent --show-error --max-time 3 "$url/"; }
wait_for_rollout() {
  local generation observed
  generation="$(k get deployment/"$deployment" -o jsonpath='{.metadata.generation}')"
  for _ in $(seq 1 60); do
    observed="$(k get deployment/"$deployment" -o jsonpath='{.status.observedGeneration}')"
    [[ "$observed" == "$generation" ]] && break
    sleep 1
  done
  [[ "$observed" == "$generation" ]] || { echo "Deployment generation $generation was not observed" >&2; return 1; }
  k rollout status deployment/"$deployment" --timeout=180s
}

command -v kubectl >/dev/null || { echo "missing required command: kubectl" >&2; exit 1; }
command -v curl >/dev/null || { echo "missing required command: curl" >&2; exit 1; }
kubectl --context "$context" cluster-info >/dev/null

section "Service availability and persistent writes"
first_response="$(service_request)"
echo "$first_response"
second_response="$(service_request)"
echo "$second_response"
first_visits="$(printf '%s' "$first_response" | grep -o '"persistent_visits": [0-9]*' | grep -o '[0-9]*')"
second_visits="$(printf '%s' "$second_response" | grep -o '"persistent_visits": [0-9]*' | grep -o '[0-9]*')"
(( second_visits > first_visits )) || { echo "persistent visit count did not increase" >&2; exit 1; }

section "Pod restart and Deployment recovery"
old_pod="$(k get pod -l app=inference-test -o jsonpath='{.items[0].metadata.name}')"
k delete pod "$old_pod" --wait=false >/dev/null
for _ in $(seq 1 60); do
  ready_count="$(k get pods -l app=inference-test --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{range .status.conditions[?(@.type=="Ready")]}{.status}{"\n"}{end}{end}' | grep -c '^True$' || true)"
  current_pods="$(k get pods -l app=inference-test -o name)"
  if [[ "$ready_count" -eq 2 ]] && ! grep -q "pod/$old_pod" <<<"$current_pods"; then break; fi
  sleep 2
done
[[ "$ready_count" -eq 2 ]] || { echo "Deployment did not recover two ready Pods" >&2; exit 1; }
service_request

section "Failed startup probe while the Service remains available"
k set env deployment/"$deployment" FAIL_STARTUP=true >/dev/null
failing_pod=""
for _ in $(seq 1 30); do
  failing_pod="$(k get pods -l app=inference-test -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.containerStatuses[0].restartCount}{" "}{range .status.conditions[?(@.type=="Ready")]}{.status}{end}{"\n"}{end}' | awk '$2 >= 1 && $3 != "True" {print $1; exit}')"
  [[ -n "$failing_pod" ]] && break
  sleep 2
done
if [[ -z "$failing_pod" ]]; then
  k set env deployment/"$deployment" FAIL_STARTUP- >/dev/null
  echo "startup probe did not restart the intentionally failing Pod" >&2
  exit 1
fi
echo "Startup probe restarted $failing_pod; healthy old Pods still serve traffic:"
service_request
k set env deployment/"$deployment" FAIL_STARTUP- >/dev/null
wait_for_rollout

section "Rolling update to v2 with zero unavailable replicas"
k patch deployment/"$deployment" --type=merge \
  -p '{"spec":{"template":{"metadata":{"labels":{"version":"v2"}}}}}' >/dev/null
# Exercise the Service while the controller replaces Pods.
for _ in $(seq 1 10); do
  service_request >/dev/null
  sleep 1
done
wait_for_rollout
response=""
for _ in $(seq 1 30); do
  response="$(service_request)"
  grep -q '"version": "v2"' <<<"$response" && break
  sleep 1
done
echo "$response"
grep -q '"version": "v2"' <<<"$response" || { echo "v2 was not served after rollout" >&2; exit 1; }

section "All Phase 2 tests passed"
k get pods,service,pvc
