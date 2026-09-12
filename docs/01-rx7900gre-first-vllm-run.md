# First vLLM run: RX 7900 GRE

**Date:** 2026-09-12  
**Result:** Successful, followed by complete targeted cleanup

## Goal

Determine whether the desktop's AMD GPU could run vLLM with a very small model and expose a working OpenAI-compatible API.

## Observed hardware

| Component | Observation |
|---|---|
| Discrete GPU | AMD Radeon RX 7900 GRE |
| Architecture | Navi 31, `gfx1100` |
| Dedicated VRAM | 15.98 GiB reported to PyTorch |
| Integrated GPU | Ryzen 5 7600X graphics, `gfx1036` |
| System RAM | 30 GiB usable/reportable |
| Kernel | Linux 6.18.48 |
| Driver | `amdgpu` |
| Compute devices | `/dev/kfd`, `/dev/dri/renderD128`, `/dev/dri/renderD129` |
| Host | NixOS, x86-64 |

The host already had Docker and Podman, and the user belonged to `docker`, `podman`, `video`, and `render` groups.

## Image and software

```text
rocm/vllm-dev:rocm7.2.1_navi_ubuntu24.04_py3.12_pytorch_2.9_vllm_0.16.0
```

Runtime verification showed:

```text
PyTorch 2.9.1+gitff65f5b
HIP 7.2.53211-e1a6bc5663
0 AMD Radeon RX 7900 GRE       15.98 GiB
1 AMD Ryzen 5 7600X graphics  15.24 GiB
```

PyTorch's ROCm backend deliberately uses APIs named `torch.cuda.*`; those names do not imply that an NVIDIA GPU or CUDA runtime was used.

## First pull failure

The first image pull failed while extracting ROCm's LLVM/flang layer:

```text
no space left on device
```

After reclaiming inactive Docker data and disposable language/tool caches, free space rose to roughly 63 GiB and the pull succeeded. The full pull/unpack/container cycle then reduced free space to about 6 GiB.

This is the most important operational lesson from the session: inspect both GPU compatibility **and storage headroom** before using large ROCm development images.

A broad `docker system prune -af` was used during this exploratory session. It removed inactive project images and build cache. Future experiments should use the targeted `scripts/cleanup.sh` instead.

## GPU verification

Inside the container, `rocminfo` identified both AMD agents. PyTorch reported two accelerator devices and successfully selected the discrete card. The server was constrained to it with:

```bash
HIP_VISIBLE_DEVICES=0
```

Never assume device numbering on another machine. Run `scripts/verify-rocm-container.sh` first.

## Serving configuration

```text
Model:                  Qwen/Qwen2.5-0.5B-Instruct
Model dtype:            FP16
Maximum model length:   2,048 tokens
GPU memory utilization: 0.75
Execution mode:         eager
API address:            http://0.0.0.0:8000
```

`--enforce-eager` was selected as a conservative first test. It disables graph capture and compilation optimizations, trading performance for compatibility and simpler startup.

## Relevant startup observations

```text
Resolved architecture: Qwen2ForCausalLM
Casting torch.bfloat16 to torch.float16
Using Triton Attention backend
Model loading took 0.99 GiB memory
Available KV cache memory: 9.25 GiB
GPU KV cache size: 808,192 tokens
Application startup complete
```

The model's 2,048-token request limit is distinct from the total number of tokens vLLM can hold across concurrent requests in its KV cache.

## API verification

A request to `/v1/chat/completions` produced a valid response. This demonstrated the complete path:

1. Host `amdgpu` driver
2. Docker device passthrough
3. ROCm/HIP device discovery
4. PyTorch tensor execution
5. vLLM model loading and attention backend
6. HTTP API serving
7. Token generation

The model saying that it ran on a Radeon was not itself proof. Device enumeration and vLLM's runtime logs provided that evidence.

## Cleanup

The following were removed after the test:

- `vllm-test` container
- ROCm/vLLM development image
- Qwen 0.5B Hugging Face cache
- Temporary cleanup image

Free disk returned to approximately 63 GiB, and no vLLM container or image remained.

## Conclusions

- The RX 7900 GRE successfully ran this vLLM/ROCm combination.
- Explicit GPU selection matters because the host also has an AMD iGPU.
- A 0.5B FP16 model requires little VRAM, but the software image requires substantial disk.
- A slimmer runtime image or larger Docker filesystem is desirable for continued work.
- Successful execution on this model does not guarantee every quantization kernel, model architecture, or optimized execution mode will work on `gfx1100`.
