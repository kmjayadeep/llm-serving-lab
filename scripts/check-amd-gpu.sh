#!/usr/bin/env bash
set -euo pipefail

printf '== AMD devices ==\n'
lspci -nnk 2>/dev/null | grep -EA3 'VGA|3D|Display' || true
ls -l /dev/kfd /dev/dri/renderD* 2>/dev/null || {
  echo 'missing /dev/kfd or /dev/dri/renderD*' >&2
  exit 1
}

printf '\n== VRAM ==\n'
for path in /sys/class/drm/card*/device/mem_info_vram_total; do
  [[ -e "$path" ]] || continue
  awk -v card="${path%/device/mem_info_vram_total}" -v bytes="$(<"$path")" \
    'BEGIN { printf "%s: %.2f GiB\n", card, bytes / 2^30 }'
done

printf '\n== Access and disk ==\n'
id
df -h /
docker --version
docker compose version
