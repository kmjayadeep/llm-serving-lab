# Homelab roadmap

## Phase 1: repeatable workstation experiments

- Keep launch configuration in Compose.
- Record image digest, model revision, flags, and hardware for each run.
- Add a benchmark harness and machine-readable results.
- Compare model sizes and context lengths.
- Find a smaller runtime image or increase container storage.

Exit criterion: the same command reliably launches, serves a test prompt, records metrics, and cleans up without affecting unrelated workloads.

## Phase 2: single-node Kubernetes

Possible lab distributions include k3s, kind, or kubeadm. A real GPU device plugin generally makes a Linux-hosted cluster preferable to nested container-only experiments.

- Install a pinned Kubernetes version.
- Label/taint the GPU node deliberately.
- Install the AMD device plugin if retaining AMD.
- Deploy the baseline vLLM pod.
- Add persistent model storage.
- Add Prometheus/Grafana and GPU metrics.
- Exercise pod restart and node reboot behavior.

Exit criterion: Kubernetes schedules the workload by GPU resource, probes behave correctly during model loading, and API tests survive controlled restarts.

## Phase 3: dedicated GPU node

Hardware selection should consider more than peak compute:

- VRAM capacity and bandwidth
- Framework/kernel support
- Idle and load power
- Cooling and physical dimensions
- PCIe lanes and platform topology
- Driver stability
- Cost per usable model size
- Multi-GPU interconnect requirements

For learning broad ecosystem compatibility, NVIDIA often has the least friction. AMD can offer attractive hardware value and is important to learn, but verify the exact SKU against ROCm, PyTorch, vLLM, quantization, and Kubernetes-plugin matrices.

Infrastructure considerations:

- Dedicated SSD for images and model artifacts
- Wired networking; faster links for distributed inference
- UPS and graceful shutdown
- Remote management
- Reproducible OS configuration, potentially through NixOS
- Firewalling and a private management network

## Phase 4: serving platform

- Gateway with TLS and authentication
- Inference-aware routing
- Horizontal scaling based on model-server metrics
- Versioned model deployments
- Load testing and service objectives
- Central logs, metrics, and traces
- Artifact distribution and cache policy
- llm-d evaluation

## Experiment record template

Each experiment should record:

```text
Date:
Question/hypothesis:
Host and kernel:
GPU and VRAM:
Driver/ROCm/PyTorch/vLLM versions:
Container image and digest:
Model ID, revision, license, and dtype/quantization:
Serving flags:
Prompt/input distribution:
Concurrency:
TTFT, ITL, throughput, memory, and power:
Errors/warnings:
Result:
Next experiment:
```

Raw artifacts should be sanitized before committing. Never include credentials, private prompts, full environment dumps, or kubeconfigs.
