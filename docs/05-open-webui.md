# Open WebUI

**Date tested:** 2026-09-13  
**Result:** Open WebUI started successfully and could reach the model exposed by vLLM.

## Purpose

vLLM provides an HTTP API but not a full conversational browser interface. Open WebUI acts as an API client and adds a familiar chat screen while vLLM continues to perform model inference.

```text
Browser → Open WebUI :3000 → vLLM :8000 → PyTorch/ROCm → AMD GPU
```

Open WebUI does not load the Qwen model onto the GPU. It sends chat-completion requests to vLLM.

## Compose configuration

Both services use host networking in this local experiment. Open WebUI connects to:

```text
http://127.0.0.1:8000/v1
```

Its browser interface listens at:

```text
http://localhost:3000
```

Open WebUI stores accounts, settings, and chat history in the named Docker volume `open-webui-data`. Removing the container does not remove that volume automatically.

## Start

From the repository root:

```bash
docker compose up -d
./scripts/wait-for-server.sh
```

Open [http://localhost:3000](http://localhost:3000). On a new data volume, create the first local account; it becomes the administrator.

The available model should include:

```text
Qwen/Qwen2.5-0.5B-Instruct
```

## Verify

Check both containers:

```bash
docker compose ps
```

Check the UI health endpoint:

```bash
curl -fsS http://localhost:3000/health
```

The completed test returned:

```json
{"status": true}
```

Connectivity from the Open WebUI container to vLLM was also verified by requesting `/v1/models`; it returned `Qwen/Qwen2.5-0.5B-Instruct`.

## Stop

```bash
docker compose down
```

This preserves Open WebUI's named data volume and chat history. Use the repository cleanup script if those should also be removed.

## Scope

This is a trusted, local-only learning setup. It does not configure TLS, external authentication, or safe internet exposure.
