# vLLM and ROCm

## vLLM's role

vLLM is an inference engine and model server. Its major capabilities include efficient KV-cache management, continuous batching, distributed execution options, model/quantization integrations, metrics, and an OpenAI-compatible API.

The server is commonly started with:

```bash
vllm serve MODEL_ID [OPTIONS]
```

A client can then use `/v1/chat/completions`, `/v1/completions`, or other supported routes. API compatibility does not mean that every OpenAI product feature or model behavior is identical.

## AMD's software stack

The simplified path is:

```text
vLLM
  ↓
PyTorch + Triton / specialized kernels
  ↓
HIP and ROCm user-space libraries
  ↓
Linux KFD/DRM interfaces
  ↓
amdgpu kernel driver
  ↓
AMD GPU
```

ROCm is not wholly contained in the kernel and not wholly contained in Docker. The host supplies the compatible kernel driver and device files; the image supplies most user-space libraries.

## Why `torch.cuda` appears on AMD

PyTorch exposes HIP accelerators through much of its existing `torch.cuda` Python API. Check `torch.version.hip` to distinguish a ROCm build:

```python
import torch
print(torch.version.hip)
print(torch.cuda.is_available())
print(torch.cuda.get_device_name(0))
```

## Device selection

This workstation exposed both a discrete GPU and an integrated GPU. Select the intended ROCm device with:

```bash
HIP_VISIBLE_DEVICES=0
```

Device ordering is machine-specific. Verify with `rocminfo` and PyTorch instead of copying an index blindly.

## Important serving flags

| Flag | Meaning |
|---|---|
| `--dtype float16` | Store/compute model tensors using FP16 where applicable |
| `--max-model-len 2048` | Bound total tokens per sequence |
| `--gpu-memory-utilization 0.75` | Fraction of visible GPU memory vLLM may target |
| `--enforce-eager` | Avoid graph capture/compilation optimizations |
| `--served-model-name NAME` | Stable model name exposed through the API |
| `--tensor-parallel-size N` | Split supported model tensors across N GPUs |

Defaults and flags evolve. Always check `vllm serve --help` for the pinned image.

## Eager and optimized execution

Eager mode is useful for compatibility testing, but it gives up optimizations. A sound progression is:

1. Prove basic generation with eager execution.
2. Record correctness, startup time, latency, throughput, memory, and errors.
3. Remove `--enforce-eager`.
4. Repeat the same workload.
5. Keep the optimized mode only if it is stable and measurably beneficial.

## Model sizing on 16 GiB

Very rough FP16 weight-only sizes are 1 GB for 0.5B, 3 GB for 1.5B, 6 GB for 3B, and 14 GB for 7B. A 7B FP16 model is therefore tight after cache and runtime overhead. Supported quantization can make larger models practical, but Radeon kernel support must be verified per format.

## Validation layers

Do not jump immediately to model serving. Validate in layers:

1. `amdgpu` owns the PCI device.
2. `/dev/kfd` and render nodes exist.
3. Container can run `rocminfo`.
4. ROCm PyTorch sees the intended GPU.
5. A small tensor operation succeeds.
6. vLLM starts with a tiny model.
7. `/health` succeeds.
8. A deterministic API request returns valid output.
9. Only then increase model size, context, concurrency, or optimization.

## Limitations

- Official support matrices may not name every consumer Radeon SKU.
- A shared `gfx` architecture does not guarantee all kernels behave identically.
- Quantization support differs between CUDA, ROCm, and CPU engines.
- Development/nightly images can regress.
- Host kernel and container ROCm version compatibility still matters.
- vLLM's rapidly evolving CLI and engine internals require version-pinned notes.
