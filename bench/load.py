#!/usr/bin/env python3
"""Closed-loop load benchmark for a running vLLM OpenAI-compatible server."""

from __future__ import annotations

import argparse
import asyncio
import csv
import json
import math
import os
import platform
import sys
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx
import yaml


@dataclass
class RequestResult:
    scenario: str
    model: str
    concurrency: int
    request_id: int
    prompt_id: str
    success: bool
    status_code: int | None
    started_at: str
    ttft_ms: float | None
    latency_ms: float
    prompt_tokens: int | None
    completion_tokens: int | None
    output_tokens_per_second: float | None
    error: str | None


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def percentile(values: list[float], percent: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    position = (len(ordered) - 1) * percent
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower)


def rounded(value: float | None) -> float | None:
    return round(value, 3) if value is not None else None


def load_config(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        config = yaml.safe_load(handle)
    if not isinstance(config, dict):
        raise ValueError("configuration must be a YAML mapping")
    for key in ("server", "benchmark", "models", "prompts"):
        if key not in config:
            raise ValueError(f"configuration is missing '{key}'")
    if not config["prompts"]:
        raise ValueError("at least one prompt is required")
    return config


def headers() -> dict[str, str]:
    result = {"Content-Type": "application/json"}
    api_key = os.getenv("OPENAI_API_KEY")
    if api_key:
        result["Authorization"] = f"Bearer {api_key}"
    return result


async def discover_models(client: httpx.AsyncClient, models_url: str) -> list[str]:
    response = await client.get(models_url, headers=headers())
    response.raise_for_status()
    return [item["id"] for item in response.json().get("data", [])]


async def send_request(
    client: httpx.AsyncClient,
    *,
    endpoint: str,
    scenario: str,
    model: str,
    concurrency: int,
    request_id: int,
    prompt: dict[str, str],
    benchmark: dict[str, Any],
) -> RequestResult:
    started_at = utc_now()
    started = time.perf_counter()
    first_token_at: float | None = None
    status_code: int | None = None
    usage: dict[str, Any] = {}
    error: str | None = None

    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt["text"]}],
        "max_tokens": benchmark["max_tokens"],
        "temperature": benchmark["temperature"],
        "stream": True,
        "stream_options": {"include_usage": True},
        # vLLM extension: keep output length controlled across requests.
        "ignore_eos": benchmark.get("ignore_eos", True),
        "seed": benchmark.get("seed", 1),
    }

    try:
        async with client.stream("POST", endpoint, headers=headers(), json=payload) as response:
            status_code = response.status_code
            response.raise_for_status()
            async for line in response.aiter_lines():
                if not line.startswith("data:"):
                    continue
                data = line[5:].strip()
                if not data or data == "[DONE]":
                    continue
                chunk = json.loads(data)
                if chunk.get("usage"):
                    usage = chunk["usage"]
                for choice in chunk.get("choices", []):
                    content = choice.get("delta", {}).get("content")
                    if content and first_token_at is None:
                        first_token_at = time.perf_counter()
    except Exception as exc:  # Preserve failures as benchmark data.
        error = f"{type(exc).__name__}: {exc}"

    finished = time.perf_counter()
    latency_seconds = finished - started
    ttft_seconds = first_token_at - started if first_token_at is not None else None
    completion_tokens = usage.get("completion_tokens")
    prompt_tokens = usage.get("prompt_tokens")

    output_rate = None
    if completion_tokens is not None and completion_tokens > 1 and first_token_at is not None:
        decode_seconds = finished - first_token_at
        if decode_seconds > 0:
            output_rate = (completion_tokens - 1) / decode_seconds

    success = error is None and status_code == 200 and first_token_at is not None
    if error is None and not success:
        error = "stream completed without an output token"

    return RequestResult(
        scenario=scenario,
        model=model,
        concurrency=concurrency,
        request_id=request_id,
        prompt_id=prompt["id"],
        success=success,
        status_code=status_code,
        started_at=started_at,
        ttft_ms=rounded(ttft_seconds * 1000 if ttft_seconds is not None else None),
        latency_ms=rounded(latency_seconds * 1000) or 0.0,
        prompt_tokens=prompt_tokens,
        completion_tokens=completion_tokens,
        output_tokens_per_second=rounded(output_rate),
        error=error,
    )


async def run_requests(
    client: httpx.AsyncClient,
    *,
    endpoint: str,
    scenario: str,
    model: str,
    concurrency: int,
    count: int,
    prompts: list[dict[str, str]],
    benchmark: dict[str, Any],
) -> tuple[list[RequestResult], float]:
    queue: asyncio.Queue[int] = asyncio.Queue()
    for request_id in range(count):
        queue.put_nowait(request_id)

    results: list[RequestResult] = []

    async def worker() -> None:
        while True:
            try:
                request_id = queue.get_nowait()
            except asyncio.QueueEmpty:
                return
            prompt = prompts[request_id % len(prompts)]
            result = await send_request(
                client,
                endpoint=endpoint,
                scenario=scenario,
                model=model,
                concurrency=concurrency,
                request_id=request_id,
                prompt=prompt,
                benchmark=benchmark,
            )
            results.append(result)
            queue.task_done()

    started = time.perf_counter()
    await asyncio.gather(*(worker() for _ in range(min(concurrency, count))))
    duration = time.perf_counter() - started
    return sorted(results, key=lambda result: result.request_id), duration


def summarize(results: list[RequestResult], duration: float) -> dict[str, Any]:
    successful = [result for result in results if result.success]
    latencies = [result.latency_ms for result in successful]
    ttfts = [result.ttft_ms for result in successful if result.ttft_ms is not None]
    request_rates = [
        result.output_tokens_per_second
        for result in successful
        if result.output_tokens_per_second is not None
    ]
    output_tokens = sum(result.completion_tokens or 0 for result in successful)

    def mean(values: list[float]) -> float | None:
        return sum(values) / len(values) if values else None

    return {
        "scenario": results[0].scenario,
        "model": results[0].model,
        "concurrency": results[0].concurrency,
        "attempted_requests": len(results),
        "successful_requests": len(successful),
        "failed_requests": len(results) - len(successful),
        "error_rate": rounded((len(results) - len(successful)) / len(results)),
        "duration_seconds": rounded(duration),
        "requests_per_second": rounded(len(successful) / duration),
        "aggregate_output_tokens_per_second": rounded(output_tokens / duration),
        "mean_request_output_tokens_per_second": rounded(mean(request_rates)),
        "mean_ttft_ms": rounded(mean(ttfts)),
        "p50_ttft_ms": rounded(percentile(ttfts, 0.50)),
        "p95_ttft_ms": rounded(percentile(ttfts, 0.95)),
        "p99_ttft_ms": rounded(percentile(ttfts, 0.99)),
        "mean_latency_ms": rounded(mean(latencies)),
        "p50_latency_ms": rounded(percentile(latencies, 0.50)),
        "p95_latency_ms": rounded(percentile(latencies, 0.95)),
        "p99_latency_ms": rounded(percentile(latencies, 0.99)),
    }


def write_outputs(
    output_dir: Path,
    metadata: dict[str, Any],
    raw_results: list[RequestResult],
    summaries: list[dict[str, Any]],
) -> None:
    output_dir.mkdir(parents=True, exist_ok=False)
    with (output_dir / "metadata.json").open("w", encoding="utf-8") as handle:
        json.dump(metadata, handle, indent=2)
        handle.write("\n")
    with (output_dir / "raw.jsonl").open("w", encoding="utf-8") as handle:
        for result in raw_results:
            handle.write(json.dumps(asdict(result)) + "\n")
    with (output_dir / "summary.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(summaries[0]))
        writer.writeheader()
        writer.writerows(summaries)


async def async_main(args: argparse.Namespace) -> int:
    config = load_config(args.config)
    declared_models = {item["id"] for item in config["models"]}
    if args.model not in declared_models:
        raise ValueError(f"model '{args.model}' is not declared in {args.config}")

    server = config["server"]
    benchmark = config["benchmark"]
    timeout = httpx.Timeout(float(server.get("timeout_seconds", 180)))

    async with httpx.AsyncClient(timeout=timeout) as client:
        available_models = await discover_models(client, server["models_url"])
        if args.model not in available_models:
            raise RuntimeError(
                f"requested model '{args.model}' is not served; available: {available_models}"
            )

        all_results: list[RequestResult] = []
        summaries: list[dict[str, Any]] = []
        for concurrency in benchmark["concurrency"]:
            scenario = f"c{concurrency}"
            warmup_count = int(benchmark.get("warmup_requests", 0))
            if warmup_count:
                await run_requests(
                    client,
                    endpoint=server["endpoint"],
                    scenario=f"{scenario}-warmup",
                    model=args.model,
                    concurrency=concurrency,
                    count=warmup_count,
                    prompts=config["prompts"],
                    benchmark=benchmark,
                )

            results, duration = await run_requests(
                client,
                endpoint=server["endpoint"],
                scenario=scenario,
                model=args.model,
                concurrency=concurrency,
                count=int(benchmark["requests_per_scenario"]),
                prompts=config["prompts"],
                benchmark=benchmark,
            )
            all_results.extend(results)
            summary = summarize(results, duration)
            summaries.append(summary)
            print(json.dumps(summary), flush=True)

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output_dir = args.output_dir / f"{timestamp}-{args.model.split('/')[-1]}"
    metadata = {
        "created_at": utc_now(),
        "config": config,
        "selected_model": args.model,
        "available_models": available_models,
        "python": sys.version,
        "platform": platform.platform(),
    }
    write_outputs(output_dir, metadata, all_results, summaries)
    print(f"results written to {output_dir}")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path("bench/scenarios.yaml"))
    parser.add_argument("--model", required=True, help="served model ID to benchmark")
    parser.add_argument("--output-dir", type=Path, default=Path("bench/results"))
    return parser.parse_args()


def main() -> int:
    try:
        return asyncio.run(async_main(parse_args()))
    except (ValueError, RuntimeError, httpx.HTTPError, OSError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
