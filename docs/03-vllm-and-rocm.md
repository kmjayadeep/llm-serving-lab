# vLLM and ROCm

## Stack

```text
vLLM
  ↓
PyTorch and inference kernels
  ↓
HIP/ROCm user-space libraries
  ↓
Linux KFD/DRM interfaces
  ↓
amdgpu kernel driver
  ↓
AMD GPU
```

The host provides the kernel driver and device files. The container provides the compatible ROCm, PyTorch, and vLLM user space.

## PyTorch device API

ROCm builds use much of PyTorch's existing `torch.cuda` API. Confirm ROCm with `torch.version.hip`:

```python
import torch
print(torch.version.hip)
print(torch.cuda.is_available())
print(torch.cuda.get_device_name(0))
```

## Device selection

This host exposes an RX 7900 GRE and a Ryzen integrated GPU. Verify ordering before setting:

```bash
HIP_VISIBLE_DEVICES=0
```

Use [`scripts/verify-rocm-container.sh`](../scripts/verify-rocm-container.sh) to inspect devices inside the selected image.

## Relevant vLLM options

| Option | Purpose |
|---|---|
| `--dtype float16` | Use FP16 model tensors where applicable |
| `--max-model-len 2048` | Limit tokens per sequence |
| `--gpu-memory-utilization 0.75` | Set vLLM's target fraction of visible GPU memory |
| `--enforce-eager` | Disable graph capture and compilation optimizations |
| `--served-model-name` | Set the model name exposed through the API |

Check `vllm serve --help` for the pinned image because the CLI changes over time.

## Validation order

1. Confirm `amdgpu` owns the PCI device.
2. Confirm `/dev/kfd` and `/dev/dri/renderD*` exist.
3. Run `rocminfo` inside the container.
4. Confirm ROCm PyTorch sees the intended GPU.
5. Start a small model.
6. Check `/health` and `/v1/models`.
7. Send a generation request.
8. Run a controlled benchmark.

## Scope

Successful execution on `gfx1100` does not guarantee support for every model architecture, quantization format, attention kernel, or optimized execution mode. Pin versions and validate changes independently.
