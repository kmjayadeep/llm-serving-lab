# Kubernetes model serving

## Why Kubernetes

Kubernetes does not make inference intrinsically faster. It helps operate serving workloads by providing declarative placement, restart behavior, networking, configuration, rollout primitives, resource accounting, and an ecosystem for autoscaling and observability.

For one workstation and one model, Compose is simpler. Kubernetes becomes educationally and operationally useful when exploring multiple nodes, replicas, accelerators, gateways, and failure recovery.

## Making AMD GPUs schedulable

A node's `/dev/kfd` existing is not enough for Kubernetes scheduling. An AMD GPU device plugin advertises GPU resources to the kubelet. Workloads can then request a resource such as:

```yaml
resources:
  limits:
    amd.com/gpu: 1
```

The exact plugin version, resource behavior, supported OS, and installation procedure must be taken from AMD's current device-plugin documentation.

Validate node resources with:

```bash
kubectl describe node NODE_NAME
kubectl get nodes -o custom-columns=NAME:.metadata.name,AMD-GPU:.status.allocatable.amd\.com/gpu
```

## Single-pod baseline

The manifests under `kubernetes/base/` illustrate:

- One vLLM Deployment
- One requested AMD GPU
- A persistent Hugging Face cache
- Readiness/liveness health checks
- A ClusterIP Service

They are not expected to work until the cluster has:

1. A compatible AMD GPU node and host driver
2. AMD's Kubernetes device plugin
3. Sufficient local/container storage
4. A suitable default StorageClass or edited PVC
5. Permission to pull the image and model

## Image and model startup

Downloading a model during pod startup is simple but creates long cold starts and depends on external networking. Alternatives include:

- Init containers
- Pre-populated persistent volumes
- Node-local model caches
- Model-aware artifact systems
- Custom images where licensing permits embedding weights

Avoid storing Hugging Face tokens directly in manifests. Use a Kubernetes Secret and narrowly scope access.

## Health probes

Readiness asks whether a pod should receive traffic. Liveness asks whether Kubernetes should restart it. Model loading can take minutes, so startup/readiness thresholds must tolerate cold starts. Aggressive liveness checks can create a crash loop while a healthy model is still loading.

## Services and gateways

A ClusterIP Service makes replicas reachable inside the cluster. External access should normally pass through an ingress or Gateway API implementation with authentication, TLS, limits, and observability.

Ordinary round-robin load balancing is not always ideal for LLM inference. Requests have different prompt lengths, output lengths, cache locality, and memory pressure. This motivates inference-aware routing projects such as llm-d.

## Autoscaling caveats

CPU utilization is rarely the best signal for an accelerator-bound model server. Better inputs may include:

- Waiting/running request counts
- Queue delay
- KV-cache utilization
- TTFT and inter-token latency
- Tokens per second
- GPU utilization and memory

GPU model replicas also have expensive cold starts, large images, and large model artifacts. Autoscaling must account for startup time and available accelerator topology.

## Production gaps in the baseline

Before treating the sample as production, add:

- Authentication and TLS
- NetworkPolicy
- Pod security settings
- Resource requests beyond the GPU
- Topology and node-affinity rules
- Pod disruption handling
- Metrics scraping and dashboards
- Log aggregation and tracing
- Secret management
- Model-license controls
- Load and failure testing
- Versioned rollback strategy
