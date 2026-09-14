# Kubernetes with kind

Phase 2 uses a CPU-only Python HTTP server as an inference stand-in. This keeps
the experiment focused on Kubernetes behavior rather than GPU device plugins,
ROCm images, or model startup time.

## Architecture

```text
localhost:8080
  -> kind control-plane port mapping
  -> NodePort Service :30080
  -> two Deployment Pods :8080
  -> shared 256 Mi PersistentVolumeClaim
```

The workload in [`k8s/phase2.yaml`](../k8s/phase2.yaml) includes:

- a `Deployment` with two replicas and a zero-unavailable rolling strategy;
- a `Service` exposed locally through the kind port mapping;
- a `ConfigMap` containing application settings and the test server;
- a dynamically provisioned `PersistentVolumeClaim` for a visit log;
- startup, readiness, and liveness HTTP probes.

The startup endpoint intentionally waits three seconds. Kubernetes does not run
liveness or readiness checks until that startup probe succeeds. The readiness
probe controls Service endpoints, while the liveness probe can restart a stuck
container.

## Prerequisites

Install Docker, `kind`, `kubectl`, and `curl`, and make sure Docker is running.
The scripts always pass `--context kind-llm-serving-lab`; they do not depend on
or modify the current kubectl context.

## Create and deploy

```bash
./scripts/kind-up.sh
```

This creates the cluster from [`kind/cluster.yaml`](../kind/cluster.yaml), applies
the manifests, waits for the rollout, and requests <http://localhost:8080>.
The command is safe to rerun.

Inspect the resources:

```bash
kubectl --context kind-llm-serving-lab -n llm-serving-lab get all,pvc
kubectl --context kind-llm-serving-lab -n llm-serving-lab describe deployment inference-test
kubectl --context kind-llm-serving-lab -n llm-serving-lab get endpointslices
```

## Run the lifecycle tests

```bash
./scripts/test-kind.sh
```

The script validates:

1. **Service and persistence:** repeated requests are load-balanced and increase
   a counter backed by the PVC.
2. **Pod restart:** one Pod is deleted and the Deployment restores two ready
   replicas; persisted data remains.
3. **Failed startup:** a rolling update sets `FAIL_STARTUP=true`. The new Pod's
   startup probe restarts it, while the old ready Pods remain available. The
   script then removes the fault and waits for recovery.
4. **Rolling update:** `APP_VERSION=v2` changes the Pod template. Requests are
   made during the rollout, and the final response must report version `v2`.

To explore the other probes manually, create and remove their marker files:

```bash
# Readiness failure removes this Pod from Service endpoints without restarting it.
POD=$(kubectl --context kind-llm-serving-lab -n llm-serving-lab get pod \
  -l app=inference-test -o jsonpath='{.items[0].metadata.name}')
kubectl --context kind-llm-serving-lab -n llm-serving-lab exec "$POD" -- touch /tmp/not-ready
kubectl --context kind-llm-serving-lab -n llm-serving-lab exec "$POD" -- rm /tmp/not-ready

# Liveness failure restarts the container after two failed checks.
kubectl --context kind-llm-serving-lab -n llm-serving-lab exec "$POD" -- touch /tmp/unhealthy
kubectl --context kind-llm-serving-lab -n llm-serving-lab get pod "$POD" -w
```

Reapplying the manifest returns the Deployment configuration to `v1`:

```bash
kubectl --context kind-llm-serving-lab apply -f k8s/phase2.yaml
```

## Cleanup

```bash
kind delete cluster --name llm-serving-lab
```

The cluster's node container owns the local persistent volume, so deleting the
cluster also deletes this experiment's stored visit data.
