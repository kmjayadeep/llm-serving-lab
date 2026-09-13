# Lightweight chat UI and proxy

**Date tested:** 2026-09-13

## Architecture

```text
Browser → NGINX :3001 → vLLM :8000 → ROCm → GPU
```

Open WebUI was tested but included features not needed for this lab. It was replaced with a static HTML/CSS/JavaScript client packaged in an approximately 26 MB NGINX Alpine image.

NGINX provides one browser origin and proxies:

```text
GET  /metrics              → vLLM /metrics
GET  /v1/models            → vLLM /v1/models
POST /v1/chat/completions  → vLLM /v1/chat/completions
```

`proxy_buffering off` preserves streamed token delivery. Longer proxy timeouts allow long generations.

## Run

```bash
docker compose up -d --build
./scripts/wait-for-server.sh
```

Open [http://localhost:3001](http://localhost:3001).

Check both services:

```bash
docker compose ps
curl -fsS http://localhost:3001/health
curl -fsS http://localhost:3001/v1/models | jq
```

## UI features

- Streaming chat
- Model discovery
- Temperature and output-token controls
- In-memory conversation history
- Browser-observed TTFT, total latency, and token rate
- Running/waiting request counts
- KV-cache usage and prefix-cache hit rate
- Prompt, generation, completion, and error counters

UI timing includes browser and proxy overhead. Use `vllm bench serve` for controlled benchmarks.

## Routing lesson

NGINX currently has one fixed upstream. It separates the client endpoint from the model server but does not perform model-aware or inference-aware routing. Envoy and llm-d EPP are planned next.

## References

- [NGINX proxy module](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [Awesome Local LLM interfaces](https://github.com/rafska/Awesome-local-LLM#user-interfaces)
