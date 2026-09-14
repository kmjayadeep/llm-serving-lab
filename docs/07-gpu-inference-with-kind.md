# GPU inference with kind

This experiment ran `qwen2.5:0.5b` on the RX 7900 GRE from a Kubernetes Pod.
A separate cluster is required because kind GPU mounts are fixed at creation.

```text
localhost:11434 -> Service -> Ollama Pod -> AMD device plugin -> ROCm -> GPU
```

## Reproduce

Requirements: Docker, kind, kubectl, curl, `/dev/kfd`, and `/dev/dri`.

```bash
kind create cluster --config kind/gpu-cluster.yaml
CTX='--context kind-llm-serving-gpu-lab'

kubectl $CTX apply -f k8s/amd-device-plugin.yaml
# Wait until the node reports amd.com/gpu.
kubectl $CTX get node \
  -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.amd\.com/gpu'

kubectl $CTX apply -f k8s/gpu-inference.yaml
kubectl $CTX -n llm-serving-gpu-lab rollout status deployment/ollama
kubectl $CTX apply -f k8s/gpu-model-pull.yaml
kubectl $CTX -n llm-serving-gpu-lab wait --for=condition=complete \
  job/pull-qwen-model --timeout=10m
```

Or run `make kind-gpu-up`.

Send one inference request:

```bash
curl http://localhost:11434/api/generate \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen2.5:0.5b","prompt":"Explain readiness probes briefly.","stream":false,"options":{"num_predict":64}}'
```

Verify placement instead of trusting generated text:

```bash
kubectl $CTX -n llm-serving-gpu-lab exec deployment/ollama -- ollama ps
kubectl $CTX -n llm-serving-gpu-lab logs deployment/ollama | grep 'inference compute'
```

## Hardware-specific detail

The device plugin advertised both the RX 7900 GRE and Raphael iGPU. The Pod
requests `amd.com/gpu: 1`; `ROCR_VISIBLE_DEVICES=0` selects the host's verified
first device. Always re-check ordering on another machine.

## Observed

```text
backend=ROCm
architecture=gfx1100
device=AMD Radeon RX 7900 GRE
placement=100% GPU
layers=25/25 offloaded
```

The 4 GiB PVC preserves the Ollama model across Pod replacement. Deleting the
kind cluster removes it. This validates development scheduling and passthrough;
production nodes should use managed AMD drivers and usually the GPU Operator.

```bash
kind delete cluster --name llm-serving-gpu-lab
```
