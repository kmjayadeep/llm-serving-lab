# GPU inference with kind

This experiment runs a small language model on the Radeon RX 7900 GRE from a
Kubernetes Pod. It deliberately uses a separate kind cluster from the CPU-only
Phase 2 workload because GPU device mounts are fixed when a kind node is
created.

## Stack

```text
localhost:11434
  -> kind NodePort mapping
  -> Ollama Service
  -> Ollama ROCm Pod
  -> AMD device plugin allocation
  -> /dev/kfd + /dev/dri
  -> Radeon RX 7900 GRE
```

The workload uses:

- the official AMD Kubernetes device plugin and an `amd.com/gpu: 1` request;
- the official Ollama ROCm image;
- `qwen2.5:0.5b`, a roughly 400 MiB model suitable for a first inference;
- a 4 GiB PVC so the downloaded model survives Pod replacement;
- startup, readiness, and liveness probes on Ollama's API;
- a NodePort mapped to <http://localhost:11434>.

Images are pinned by digest to the versions validated in this experiment.

## Hardware-specific choice

The host exposes two ROCm devices: the discrete RX 7900 GRE and the integrated
Raphael GPU. The AMD device plugin advertises both. The Pod requests one GPU and
sets `ROCR_VISIBLE_DEVICES=0`, matching the recorded host enumeration where the
RX 7900 GRE is device zero. The test also checks Ollama's discovery log for the
exact GPU name rather than accepting CPU or iGPU execution.

## Create the cluster and deploy

Docker, kind, kubectl, curl, Python 3, `/dev/kfd`, and `/dev/dri` are required.
The setup downloads the Ollama ROCm image and model on its first run.

```bash
make kind-gpu-up
```

The script:

1. creates the GPU-specific kind cluster;
2. verifies device files inside the kind node;
3. installs the AMD device plugin;
4. waits for `amd.com/gpu` resources;
5. deploys Ollama and its persistent volume;
6. runs a Job that pulls `qwen2.5:0.5b`.

It preserves the kubectl context that was active before the command.

Inspect GPU allocation:

```bash
kubectl --context kind-llm-serving-gpu-lab get nodes \
  -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.amd\.com/gpu'
kubectl --context kind-llm-serving-gpu-lab -n llm-serving-gpu-lab \
  describe pod -l app=ollama
```

## Run inference

```bash
make kind-gpu-test
```

The test sends a non-streaming generation request, verifies a non-empty result,
checks `ollama ps` for GPU placement, and confirms the server discovered
`AMD Radeon RX 7900 GRE` with the ROCm backend.

Call the API directly:

```bash
curl http://localhost:11434/api/generate \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen2.5:0.5b",
    "prompt": "Explain a Kubernetes readiness probe in one sentence.",
    "stream": false,
    "options": {"num_predict": 64}
  }'
```

Useful diagnostics:

```bash
kubectl --context kind-llm-serving-gpu-lab -n llm-serving-gpu-lab logs deployment/ollama
kubectl --context kind-llm-serving-gpu-lab -n llm-serving-gpu-lab exec deployment/ollama -- ollama ps
kubectl --context kind-llm-serving-gpu-lab -n kube-system logs daemonset/amdgpu-device-plugin
```

## What this validates

The completed test reported:

- backend: ROCm;
- architecture: `gfx1100`;
- accelerator: `AMD Radeon RX 7900 GRE`;
- model placement: `100% GPU`;
- all 25 model layers offloaded to the GPU.

This is a development setup, not a production GPU cluster. kind runs Kubernetes
inside a privileged Docker container, and the host driver/device files are
passed into that node. A production cluster would install and manage the AMD
GPU stack directly on dedicated worker nodes, normally through the AMD GPU
Operator or equivalent node provisioning.

## Cleanup

```bash
make kind-gpu-down
```

Deleting the cluster removes its PVC and downloaded Ollama model. The CPU-only
`llm-serving-lab` kind cluster is unaffected.
