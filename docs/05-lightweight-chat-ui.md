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
Browser :3001 → vLLM :8000 → Qwen model → Radeon GPU
```

The UI has no backend, database, accounts, or additional container. Python only serves its static files. The browser sends requests directly to vLLM.

Port 3001 is used because the earlier Open WebUI experiment registered browser data on port 3000. A different origin avoids stale Open WebUI cache or service-worker behavior.

## Start

Start vLLM:

```bash
docker compose up -d
./scripts/wait-for-server.sh
```

In a separate terminal, serve the UI:

```bash
./scripts/serve-ui.sh
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

The static server binds only to `127.0.0.1`. This remains a local learning interface and should not be exposed directly to an untrusted network.
