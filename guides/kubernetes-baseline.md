# Guide: Kubernetes baseline

The manifests in `kubernetes/base` are a learning scaffold, not a complete cluster installation.

## Prerequisites

1. A Linux Kubernetes node with compatible AMD driver support
2. AMD GPU device plugin installed and healthy
3. `amd.com/gpu` visible in node allocatable resources
4. A default StorageClass or an edited PVC
5. Sufficient disk and internet/model-registry access
6. `kubectl` configured for the intended lab cluster

## Inspect accelerator capacity

```bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,AMD-GPU:.status.allocatable.amd\.com/gpu
```

Do not continue if the intended node has no advertised GPU.

## Review and deploy

Read every manifest first, especially image size, model, storage, and resource requests:

```bash
kubectl kustomize kubernetes/base
kubectl apply -k kubernetes/base
kubectl -n llm-serving-lab get pods -w
```

Inspect startup:

```bash
kubectl -n llm-serving-lab logs -f deployment/vllm
kubectl -n llm-serving-lab describe pod -l app=vllm
```

## Access locally

```bash
kubectl -n llm-serving-lab port-forward service/vllm 8000:8000
```

In another terminal:

```bash
./scripts/test-api.sh
```

## Remove

```bash
kubectl delete -k kubernetes/base
```

PVC behavior depends on the StorageClass and reclaim policy. Confirm whether backing storage remains after deletion.

## Next improvements

- Replace floating model downloads with revision-pinned artifacts
- Add a Secret for gated-model credentials
- Add CPU and memory requests based on measurements
- Add node affinity and accelerator labels
- Install Prometheus scraping
- Put an authenticated Gateway in front
- Load test multiple replicas before exploring llm-d routing
