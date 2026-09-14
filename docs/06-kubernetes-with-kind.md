# Kubernetes with kind

A CPU-only HTTP server isolates Kubernetes behavior from GPU complexity.

```text
localhost:8080 -> NodePort -> Service -> 2 Pods -> shared PVC
```

[`k8s/phase2.yaml`](../k8s/phase2.yaml) contains the Deployment, Service,
ConfigMap, 256 MiB PVC, and all three probes.

## Reproduce

Requirements: Docker, kind, kubectl, and curl.

```bash
kind create cluster --config kind/cluster.yaml
kubectl --context kind-llm-serving-lab apply -f k8s/phase2.yaml
kubectl --context kind-llm-serving-lab -n llm-serving-lab \
  rollout status deployment/inference-test
curl http://localhost:8080
```

Or run `make kind-up`.

## Probe model

| Probe | Purpose | Test endpoint |
|---|---|---|
| Startup | Delay other probes until startup succeeds | `/startup` |
| Readiness | Add/remove Pod from Service endpoints | `/ready` |
| Liveness | Restart an unhealthy container | `/live` |

## Lifecycle experiments

```bash
CTX='--context kind-llm-serving-lab -n llm-serving-lab'

# Deployment replaces a deleted Pod.
POD=$(kubectl $CTX get pod -l app=inference-test -o jsonpath='{.items[0].metadata.name}')
kubectl $CTX delete pod "$POD"

# A bad startup rolls back safely because maxUnavailable is zero.
kubectl $CTX set env deployment/inference-test FAIL_STARTUP=true
kubectl $CTX get pods -w
curl http://localhost:8080
kubectl $CTX set env deployment/inference-test FAIL_STARTUP-

# Changing the Pod template triggers a rolling update.
kubectl $CTX patch deployment/inference-test --type=merge \
  -p '{"spec":{"template":{"metadata":{"labels":{"version":"v2"}}}}}'
kubectl $CTX rollout status deployment/inference-test
curl http://localhost:8080
```

`make kind-test` runs these checks automatically.

## Learned

- Deployments restore desired state.
- Readiness controls traffic; liveness controls restarts.
- Healthy old Pods keep serving during a failed startup or rolling update.
- PVC data survives Pod replacement but not deletion of this kind cluster.

```bash
kind delete cluster --name llm-serving-lab
```
