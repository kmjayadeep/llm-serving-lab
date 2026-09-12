# Hardware observations

Captured and sanitized during the first experiment on 2026-09-12.

## Host

| Component | Observation |
|---|---|
| System RAM | 30 GiB usable/reportable |
| CPU | AMD Ryzen 5 7600X 6-Core Processor |
| Architecture | x86-64 |
| Kernel | Linux 6.18.48 |
| GPU driver | `amdgpu` |

## Display devices

- AMD Navi 31 — Radeon RX 7900 XT/XTX/GRE/7900M PCI family
- AMD Raphael integrated graphics

The discrete GPU reported `17,163,091,968` bytes, or approximately **15.98 GiB**, through sysfs.

## Compute device files

```text
/dev/kfd
/dev/dri/renderD128
/dev/dri/renderD129
```

## Container discovery

| Property | Result |
|---|---|
| PyTorch | `2.9.1+gitff65f5b` |
| HIP | `7.2.53211-e1a6bc5663` |
| Accelerator available | `true` |
| Device 0 | AMD Radeon RX 7900 GRE, 15.98 GiB |
| Device 1 | AMD Ryzen 5 7600X integrated graphics, 15.24 GiB reported shared memory |
