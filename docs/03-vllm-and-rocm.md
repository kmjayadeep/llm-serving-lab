# vLLM and ROCm

## Stack

```text
vLLM -> PyTorch/kernels -> ROCm -> /dev/kfd + /dev/dri -> amdgpu -> GPU
```

The host supplies the kernel driver and device files. The container supplies the
matching ROCm, PyTorch, and vLLM user space.

ROCm builds retain PyTorch's `torch.cuda` API:

```python
import torch
print(torch.version.hip)
print(torch.cuda.is_available())
print(torch.cuda.get_device_name(0))
```

## Reproducible validation order

1. Check that `amdgpu` owns the PCI device.
2. Check `/dev/kfd` and `/dev/dri/renderD*`.
3. Run `rocminfo` and PyTorch inside the image.
4. Select the verified GPU with `HIP_VISIBLE_DEVICES`.
5. Start a small model and check `/health` and `/v1/models`.
6. Generate text, inspect GPU logs, then benchmark.

## Important vLLM flags

| Flag | Why |
|---|---|
| `--dtype float16` | FP16 tensors |
| `--max-model-len 2048` | Bound sequence and KV-cache use |
| `--gpu-memory-utilization 0.75` | Leave VRAM headroom |
| `--enforce-eager` | Compatibility-first execution |
| `--served-model-name` | Stable API model name |

Pin the image. A working `gfx1100` setup does not guarantee every model,
quantization, kernel, or newer release will work.
