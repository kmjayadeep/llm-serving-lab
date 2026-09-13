# Lightweight chat UI

**Date tested:** 2026-09-13

## What we learned

vLLM provides an OpenAI-compatible HTTP API, not a full chat application. Any compatible client can sit in front of it:

```text
Chat client → vLLM API → PyTorch/ROCm → AMD GPU
```

Open WebUI was tested first. It connected successfully, but it also provides accounts, persistent chat storage, embeddings, document features, tools, and other capabilities that this early lab does not need. Its container and data volume were removed.

The [Awesome Local LLM user-interface list](https://github.com/rafska/Awesome-local-LLM#user-interfaces) was reviewed. Page Assist is a lighter existing option with OpenAI-compatible endpoint support, but it requires installing a browser extension. LobeChat, Text Generation WebUI, and SillyTavern provide broader feature sets than this experiment requires.

For now, the repository uses a small static HTML, CSS, and JavaScript client. Reading its source makes the API interaction visible and keeps the experiment focused.

## Architecture

```text
Browser → NGINX UI/proxy :3001 → vLLM :8000 → Qwen model → Radeon GPU
```

The UI has no application backend, database, accounts, or JavaScript framework. A small NGINX Alpine container serves its static files and forwards `/v1` and `/metrics` to vLLM. The browser therefore uses one origin and does not need direct cross-origin access to port 8000. The built UI image measured approximately 26 MB.

## What the proxy adds

The browser now requests relative paths from NGINX:

```text
GET  /metrics
GET  /v1/models
POST /v1/chat/completions
```

NGINX separates the client-facing endpoint from the model-server endpoint. Its `proxy_buffering off` setting is important: buffering could delay streamed tokens instead of forwarding them as they arrive. Extended read/send timeouts allow longer generations.

This is the repository's first simple routing layer. It has one fixed upstream and does not yet perform load balancing or inference-aware routing.

Port 3001 is used because the earlier Open WebUI experiment registered browser data on port 3000. A different origin avoids stale Open WebUI cache or service-worker behavior.

## Start

Build and start vLLM and the UI:

```bash
docker compose up -d --build
./scripts/wait-for-server.sh
```

Open [http://localhost:3001](http://localhost:3001).

## Current features

- Discovers available models from `/v1/models`
- Sends chat history to `/v1/chat/completions`
- Streams generated text as it arrives
- Supports temperature and maximum-token controls
- Clears the current in-memory conversation
- Displays approximate browser-observed time to first token, total time, and output tokens per second
- Polls vLLM's Prometheus endpoint for running/waiting requests, KV-cache use, token counters, completed requests, and errors
- Shows both cumulative and per-request prefix-cache hit rates

Conversation history exists only in the current page. Reloading or pressing **New chat** clears it.

## Prefix-cache metrics

vLLM exports token counters through `/metrics`:

```text
vllm:prefix_cache_queries_total
vllm:prefix_cache_hits_total
```

The server panel calculates cumulative hit rate since startup as `hits / queries`. For the last chat request, the UI snapshots both counters before and after generation and applies the same calculation to their differences.

The per-request value is approximate if other clients are using the server concurrently. A short prompt can also report that no cacheable prefix was measured because prefix caching operates on token blocks rather than arbitrary individual tokens.

## Measurement caveat

The UI metrics are useful for interactive observation, not rigorous benchmarking. They include browser and HTTP overhead. Use vLLM's benchmark command for controlled measurements across fixed prompts, output lengths, warmups, and concurrency.

## Security scope

The NGINX container uses host networking but binds only to `127.0.0.1:3001`. This remains a local learning interface and should not be exposed to an untrusted network.
