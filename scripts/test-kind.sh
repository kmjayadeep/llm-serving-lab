#!/usr/bin/env bash
set -euo pipefail

ctx=(--context kind-llm-serving-lab -n llm-serving-lab)
k() { kubectl "${ctx[@]}" "$@"; }
request() { curl -fsS --max-time 3 http://localhost:8080/; }

printf '\n== Service and PVC ==\n'
a=$(request); b=$(request)
echo "$a"; echo "$b"
av=$(grep -o '"persistent_visits": [0-9]*' <<<"$a" | grep -o '[0-9]*')
bv=$(grep -o '"persistent_visits": [0-9]*' <<<"$b" | grep -o '[0-9]*')
(( bv > av ))

printf '\n== Pod replacement ==\n'
pod=$(k get pod -l app=inference-test -o jsonpath='{.items[0].metadata.name}')
k delete pod "$pod"
k wait --for=condition=ready pod -l app=inference-test --timeout=2m
request

printf '\n== Failed startup; old Pods remain available ==\n'
trap 'k set env deployment/inference-test FAIL_STARTUP- >/dev/null 2>&1 || true' EXIT
k set env deployment/inference-test FAIL_STARTUP=true
sleep 20
k get pods
request
restarts=$(k get pods -l app=inference-test \
  -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{"\n"}{end}' |
  awk '{n += $1} END {print n + 0}')
(( restarts > 0 ))
k set env deployment/inference-test FAIL_STARTUP-
sleep 1
k rollout status deployment/inference-test --timeout=3m
trap - EXIT

printf '\n== Rolling update ==\n'
k patch deployment/inference-test --type=merge \
  -p '{"spec":{"template":{"metadata":{"labels":{"version":"v2"}}}}}'
sleep 1
k rollout status deployment/inference-test --timeout=3m
for _ in {1..30}; do
  response=$(request)
  grep -q '"version": "v2"' <<<"$response" && break
  sleep 1
done
echo "$response"
grep -q '"version": "v2"' <<<"$response"
