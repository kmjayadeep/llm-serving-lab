#!/usr/bin/env bash
set -euo pipefail

image="${VLLM_IMAGE:-rocm/vllm-dev:rocm7.2.1_navi_ubuntu24.04_py3.12_pytorch_2.9_vllm_0.16.0}"

docker run --rm \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add video \
  --ipc=host \
  --entrypoint /bin/bash \
  "$image" -lc '
    rocminfo | grep -E "Name:|Marketing Name" | head -20
    python - <<"PY"
import torch
print("PyTorch:", torch.__version__)
print("HIP:", torch.version.hip)
print("Accelerator available:", torch.cuda.is_available())
print("Device count:", torch.cuda.device_count())
for index in range(torch.cuda.device_count()):
    props = torch.cuda.get_device_properties(index)
    print(index, torch.cuda.get_device_name(index), f"{props.total_memory / 2**30:.2f} GiB")
PY
  '
