#!/usr/bin/env bash
set -euo pipefail

printf '== Host ==\n'
uname -srmo
printf '\n== Disk ==\n'
df -h /

printf '\n== AMD PCI devices ==\n'
if command -v lspci >/dev/null; then
  lspci -nnk | grep -EA3 'VGA|3D|Display' || true
else
  echo 'lspci is not installed'
fi

printf '\n== ROCm device files ==\n'
for path in /dev/kfd /dev/dri/renderD*; do
  if [[ -e "$path" ]]; then
    ls -l "$path"
  else
    echo "missing: $path"
  fi
done

printf '\n== VRAM reported by amdgpu ==\n'
found=0
for path in /sys/class/drm/card*/device/mem_info_vram_total; do
  [[ -e "$path" ]] || continue
  found=1
  bytes=$(<"$path")
  awk -v card="${path%/device/mem_info_vram_total}" -v bytes="$bytes" \
    'BEGIN { printf "%s: %.2f GiB\n", card, bytes / 1024 / 1024 / 1024 }'
done
(( found )) || echo 'No amdgpu VRAM sysfs entries found'

printf '\n== User groups ==\n'
id

printf '\n== Container tools ==\n'
docker --version 2>/dev/null || echo 'Docker not found'
docker compose version 2>/dev/null || echo 'Docker Compose plugin not found'

cat <<'EOF'

Expected for ROCm containers:
  * amdgpu is the kernel driver in use
  * /dev/kfd and at least one /dev/dri/renderD* exist
  * the user can access Docker and belongs to video/render as required
  * ample disk is available (the tested development image is very large)
EOF
