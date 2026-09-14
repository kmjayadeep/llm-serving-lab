# Lightweight chat UI

```text
Browser -> NGINX :3001 -> vLLM :8000 -> ROCm -> GPU
```

A static HTML/CSS/JavaScript client replaced Open WebUI to keep the lab focused.
NGINX serves the files and proxies:

```text
GET  /metrics
GET  /v1/models
POST /v1/chat/completions
```

`proxy_buffering off` preserves streamed tokens. The UI provides model
selection, chat controls, streaming, and basic latency/cache metrics.

## Run

```bash
docker compose up -d --build
./scripts/wait-for-server.sh
```

Open <http://localhost:3001>.

Browser timing includes proxy and rendering overhead. Use the benchmark harness
for controlled measurements.

NGINX currently has one fixed upstream. It provides a stable client endpoint,
not inference-aware routing.
