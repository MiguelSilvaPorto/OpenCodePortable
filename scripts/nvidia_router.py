#!/usr/bin/env python3
"""
NVIDIA Model Router — Proxy server that routes requests across free NVIDIA models
with intelligent stickiness (keep using fast model until it slows down),
round-robin fallback, and RPM limit monitoring.

Usage:
  set NVIDIA_API_KEY=nvapi-...
  python scripts/nvidia_router.py
  # Server starts on http://localhost:9393
"""

import os
import sys
import json
import time
import asyncio
import logging
from collections import deque
from datetime import datetime, timezone

import httpx
from starlette.applications import Starlette
from starlette.responses import StreamingResponse, JSONResponse, Response
from starlette.requests import Request
from starlette.routing import Route

logging.basicConfig(level=logging.INFO, format='%(asctime)s [NVR] %(levelname)s %(message)s')
log = logging.getLogger('nvidia-router')

def _load_nvidia_key():
    """Load NVIDIA_API_KEY from env, .env file, or opencode auth.json."""
    key = os.environ.get('NVIDIA_API_KEY', '')
    if key:
        return key

    # Try .env file in project root
    for env_path in [
        os.path.join(os.path.dirname(__file__), '..', '.env'),
        os.path.join(os.path.dirname(__file__), '..', '.env.local'),
    ]:
        full = os.path.normpath(env_path)
        if os.path.isfile(full):
            with open(full, encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line.startswith('NVIDIA_API_KEY='):
                        val = line.split('=', 1)[1].strip().strip('"').strip("'")
                        if val and not val.startswith('#'):
                            return val

    # Try opencode auth.json
    auth_path = os.path.expanduser('~/.local/share/opencode/auth.json')
    if os.path.isfile(auth_path):
        try:
            with open(auth_path, encoding='utf-8') as f:
                auth = json.load(f)
            nvidia = auth.get('nvidia', {})
            key = nvidia.get('key', '')
            if key:
                log.info(f"Loaded NVIDIA_API_KEY from {auth_path}")
                return key
        except Exception as e:
            log.warning(f"Could not read auth.json: {e}")

    return ''

NVIDIA_API_KEY = _load_nvidia_key()
NVIDIA_BASE_URL = 'https://integrate.api.nvidia.com/v1'

PORT = int(os.environ.get('NVIDIA_ROUTER_PORT', '9393'))
RPM_LIMIT = int(os.environ.get('NVIDIA_ROUTER_MAX_RPM', '40'))
RPM_WARN_FACTOR = 0.75          # Warn at 75% of limit
CHUNK_SLOW_THRESHOLD = 15.0     # seconds — mark model as "slow" if chunk takes this long
REQUEST_SLOW_THRESHOLD = 30.0   # seconds — total request considered slow
POLL_INTERVAL = 1.5             # seconds between 202 status polls
POLL_MAX_WAIT = 120.0           # max total seconds to wait for async completion

PRIMARY_MODELS = [
    {
        "id": "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning",
        "capabilities": ["text", "image", "video", "speech", "tool_call"],
        "max_tokens": 131072,
    },
    {
        "id": "google/gemma-4-31b-it",
        "capabilities": ["text", "image", "tool_call"],
        "max_tokens": 131072,
    },
    {
        "id": "mistralai/mistral-medium-3.5-128b",
        "capabilities": ["text", "tool_call"],
        "max_tokens": 131072,
    },
    {
        "id": "meta/llama-3.3-70b-instruct",
        "capabilities": ["text", "tool_call"],
        "max_tokens": 131072,
    },
    {
        "id": "deepseek-ai/deepseek-v4-flash",
        "capabilities": ["text", "tool_call"],
        "max_tokens": 131072,
    },
]

# Additional fallback models (tried if all 5 primary fail)
FALLBACK_MODELS = [
    "qwen/qwen3-next-80b-a3b-instruct",
    "moonshotai/kimi-k2-instruct",
    "meta/llama-3.1-70b-instruct",
    "microsoft/phi-4-mini-instruct",
    "mistralai/mixtral-8x22b-instruct",
    "minimaxai/minimax-m2.7",
    "stepfun-ai/step-3-5-flash",
]

# --- State ---

class RouterState:
    def __init__(self):
        self.models = []
        for i, m in enumerate(PRIMARY_MODELS):
            self.models.append({
                **m,
                "status": "unknown",   # "fast", "slow", "unknown", "dead"
                "last_latency": 0.0,
                "last_used": 0.0,
                "failures": 0,
            })
        self.fallback_used = list(FALLBACK_MODELS)  # copy, we'll consume from it
        self.active_idx = 0         # index into model queue
        self.model_queue = list(range(len(PRIMARY_MODELS)))  # rotation order
        self.rpm_timestamps = deque(maxlen=RPM_LIMIT * 2)
        self.total_requests = 0
        self.total_failures = 0
        self.lock = asyncio.Lock()

    async def record_request(self):
        async with self.lock:
            now = time.time()
            self.rpm_timestamps.append(now)
            self.total_requests += 1
            # Clean old entries (> 60s)
            while self.rpm_timestamps and now - self.rpm_timestamps[0] > 60:
                self.rpm_timestamps.popleft()

    async def rpm_current(self) -> int:
        async with self.lock:
            now = time.time()
            while self.rpm_timestamps and now - self.rpm_timestamps[0] > 60:
                self.rpm_timestamps.popleft()
            return len(self.rpm_timestamps)

    async def rpm_warning(self) -> str | None:
        rpm = await self.rpm_current()
        if rpm >= RPM_LIMIT * RPM_WARN_FACTOR:
            return (
                f"NVIDIA API: ~{rpm} de {RPM_LIMIT} RPM atingidos nos ultimos 60s. "
                f"Proximas requisicoes podem ser rejeitadas. "
                f"Solicite upgrade para 200 RPM em build.nvidia.com."
            )
        return None

    async def get_active_model(self) -> dict:
        async with self.lock:
            idx = self.model_queue[self.active_idx]
            return self.models[idx]

    async def mark_slow(self) -> int:
        """Mark active model as slow, advance to next. Returns new active model index."""
        async with self.lock:
            old_idx = self.model_queue[self.active_idx]
            self.models[old_idx]["status"] = "slow"
            self.models[old_idx]["failures"] += 1
            # Move slow model to end of queue
            self.model_queue.pop(self.active_idx)
            self.model_queue.append(old_idx)
            # Active index stays same (points to the next model that shifted into position)
            if self.active_idx >= len(self.model_queue):
                self.active_idx = 0
            new_idx = self.model_queue[self.active_idx]
            log.info(f"Model {self.models[old_idx]['id']} marked slow -> switching to {self.models[new_idx]['id']}")
            return new_idx

    async def mark_fast(self, latency: float):
        async with self.lock:
            idx = self.model_queue[self.active_idx]
            self.models[idx]["status"] = "fast"
            self.models[idx]["last_latency"] = latency
            self.models[idx]["last_used"] = time.time()
            self.models[idx]["failures"] = 0

    async def record_failure(self):
        async with self.lock:
            self.total_failures += 1

    async def get_next_fallback(self) -> str | None:
        async with self.lock:
            if self.fallback_used:
                return self.fallback_used.pop(0)
            return None

    async def reset_fallbacks(self):
        async with self.lock:
            self.fallback_used = list(FALLBACK_MODELS)

    def status_report(self) -> dict:
        return {
            "active_model": self.models[self.model_queue[self.active_idx]]["id"],
            "models": [{"id": m["id"], "status": m["status"], "latency": m["last_latency"]} for m in self.models],
            "total_requests": self.total_requests,
            "total_failures": self.total_failures,
            "rpm": len(self.rpm_timestamps),
        }


state = RouterState()


# --- NVIDIA API Client ---

async def call_nvidia_model(
    model_id: str,
    body: dict,
    stream: bool,
    timeout: float = 60.0,
) -> tuple[int, dict | None, httpx.Response | None]:
    """
    Call NVIDIA NIM API for a specific model.
    Returns (status_code, json_body_or_None, raw_response_or_None).
    Handles both sync (200) and async (202 → poll) models.
    """
    headers = {
        "Authorization": f"Bearer {NVIDIA_API_KEY}",
        "Content-Type": "application/json",
        "Accept": "text/event-stream" if stream else "application/json",
    }

    request_body = {**body, "model": model_id, "stream": stream}

    async with httpx.AsyncClient(timeout=httpx.Timeout(timeout)) as client:
        # Phase 1: Send request
        try:
            response = await client.post(
                f"{NVIDIA_BASE_URL}/chat/completions",
                headers=headers,
                json=request_body,
            )
        except httpx.TimeoutException:
            log.warning(f"Timeout contacting {model_id}")
            return 408, None, None
        except Exception as e:
            log.warning(f"Error contacting {model_id}: {e}")
            return 500, None, None

        # Phase 2: Handle response
        status = response.status_code

        if status == 200:
            return 200, None, response

        if status == 202:
            # Async model — poll for result
            body_json = response.json()
            op_id = None
            # Try various field names for the operation ID
            if isinstance(body_json, dict):
                op_id = body_json.get("id") or body_json.get("requestId") or body_json.get("operationId")
            if not op_id:
                op_id = response.headers.get("NVCF-REQID") or response.headers.get("x-request-id")

            if not op_id:
                log.warning(f"202 from {model_id} but no operation ID found")
                return 202, body_json, None

            # Poll
            poll_url = f"{NVIDIA_BASE_URL}/chat/completions/{op_id}"
            elapsed = 0.0
            while elapsed < POLL_MAX_WAIT:
                await asyncio.sleep(POLL_INTERVAL)
                elapsed += POLL_INTERVAL
                try:
                    poll_resp = await client.get(poll_url, headers=headers)
                    if poll_resp.status_code == 200:
                        return 200, None, poll_resp
                    if poll_resp.status_code == 202:
                        continue
                    # Unexpected status
                    log.warning(f"Poll returned {poll_resp.status_code} for {model_id}")
                    return poll_resp.status_code, None, None
                except Exception as e:
                    log.warning(f"Poll error for {model_id}: {e}")
                    continue

            log.warning(f"Timed out waiting for async {model_id}")
            return 408, None, None

        if status == 429:
            log.warning(f"Rate limit (429) from {model_id}")
            return 429, (response.json() if response.content else {"error": "rate limited"}), None

        # Other errors
        try:
            error_body = response.json() if response.content else {"error": str(status)}
        except Exception:
            error_body = {"error": response.text[:200] if response.text else str(status)}

        log.warning(f"Error {status} from {model_id}: {str(error_body)[:200]}")
        return status, error_body, None


# --- OpenAI proxy helpers ---

def build_rpm_notice() -> str:
    rpm = len(state.rpm_timestamps)
    return (
        f"[NVIDIA Router] ATENCAO: ~{rpm} de {RPM_LIMIT} RPM nos ultimos 60s. "
        f"Proximas requisicoes podem ser bloqueadas. "
        f"Solicite upgrade para 200 RPM em https://build.nvidia.com\n\n"
    )


async def generate_sse_stream(nvidia_response: httpx.Response, rpm_notice: str | None):
    """Forward SSE stream from NVIDIA to opencode, with optional RPM notice prefix."""
    if rpm_notice:
        notice_chunk = {
            "id": "nvidia-rpm-notice",
            "object": "chat.completion.chunk",
            "created": int(time.time()),
            "model": "nvidia-router",
            "choices": [{"index": 0, "delta": {"content": rpm_notice}, "finish_reason": None}],
        }
        yield f"data: {json.dumps(notice_chunk, ensure_ascii=False)}\n\n"

    first_chunk_time = None
    chunk_count = 0
    async for line in nvidia_response.aiter_lines():
        if not line or not line.startswith("data:"):
            continue
        chunk_count += 1
        data_str = line[5:].strip()
        if data_str == "[DONE]":
            yield "data: [DONE]\n\n"
            continue

        if first_chunk_time is None:
            first_chunk_time = time.time()
        else:
            now = time.time()
            if first_chunk_time and (now - first_chunk_time) > CHUNK_SLOW_THRESHOLD:
                first_chunk_time = None  # Reset — already flagged as slow

        # Passthrough the chunk but replace model name
        try:
            chunk = json.loads(data_str)
            chunk["model"] = chunk.get("model", "nvidia-router")
            yield f"data: {json.dumps(chunk, ensure_ascii=False)}\n\n"
        except json.JSONDecodeError:
            yield f"data: {data_str}\n\n"

    log.debug(f"Streamed {chunk_count} chunks")


# --- Routes ---

async def list_models(request: Request):
    """GET /v1/models — return available models."""
    models_list = []

    # Auto-routing model (smart selection)
    models_list.append({
        "id": "auto",
        "object": "model",
        "created": 0,
        "owned_by": "nvidia-router",
        "description": "Auto-routing: picks the best NVIDIA model based on request and performance",
    })

    # Primary models
    for m in state.models:
        models_list.append({
            "id": m["id"],
            "object": "model",
            "created": 0,
            "owned_by": m["id"].split("/")[0],
            "status": m["status"],
        })
    # Fallback models
    for fm in FALLBACK_MODELS:
        models_list.append({
            "id": fm,
            "object": "model",
            "created": 0,
            "owned_by": fm.split("/")[0],
            "status": "fallback",
        })
    return JSONResponse({"object": "list", "data": models_list})


async def chat_completions(request: Request):
    """POST /v1/chat/completions — main proxy endpoint."""
    if not NVIDIA_API_KEY:
        return JSONResponse(
            {"error": "NVIDIA_API_KEY not set in environment"},
            status_code=500,
        )

    # Read request body
    try:
        body = await request.json()
    except Exception:
        return JSONResponse({"error": "Invalid JSON body"}, status_code=400)

    stream = body.get("stream", False)
    requested_model = body.get("model", "auto")
    start_time = time.time()

    # Record RPM
    await state.record_request()
    rpm_warning = await state.rpm_warning()

    # --- Direct model call (user selected a specific model) ---
    if requested_model != "auto":
        log.info(f"Direct call to {requested_model} (stream={stream})")
        status, error_body, response = await call_nvidia_model(
            requested_model, body, stream,
            timeout=REQUEST_SLOW_THRESHOLD * 2,
        )
        if status == 200 and response:
            if stream:
                return StreamingResponse(
                    generate_sse_stream(response, rpm_warning),
                    media_type="text/event-stream",
                    headers={"x-nvidia-router-model": requested_model},
                )
            else:
                resp_body = response.json()
                resp_body["model"] = f"nvidia-router/{requested_model}"
                return JSONResponse(resp_body)
        elif status == 429:
            rpm = await state.rpm_current()
            return JSONResponse({
                "error": f"Rate limited (429) on {requested_model}. RPM: {rpm}/{RPM_LIMIT}. Aguarde ~60s.",
                "nvidia_router": {"model": requested_model, "rpm": rpm, "rpm_limit": RPM_LIMIT},
            }, status_code=429)
        else:
            return JSONResponse({
                "error": f"Model {requested_model} failed with status {status}",
                "nvidia_router": {"model": requested_model, "status": status},
            }, status_code=status or 500)

    # --- Auto-routing: smart model selection ---
    active = await state.get_active_model()
    model_id = active["id"]
    log.info(f"Auto-routing to {model_id} (status={active['status']}, stream={stream})")

    # Try primary models (start from current active, rotate through all)
    tried = 0
    all_primary_failed = False

    while tried < len(PRIMARY_MODELS) * 2:  # max 2 full rotations
        model = await state.get_active_model()
        model_id = model["id"]

        status, error_body, response = await call_nvidia_model(
            model_id, body, stream,
            timeout=REQUEST_SLOW_THRESHOLD * 2,
        )

        if status == 200 and response:
            elapsed = time.time() - start_time
            if elapsed < REQUEST_SLOW_THRESHOLD:
                await state.mark_fast(elapsed)
                log.info(f"Model {model_id} responded in {elapsed:.1f}s")
            else:
                await state.mark_slow()
                log.info(f"Model {model_id} slow ({elapsed:.1f}s) — will rotate next request")

            # Return the response
            if stream:
                return StreamingResponse(
                    generate_sse_stream(response, rpm_warning),
                    media_type="text/event-stream",
                    headers={
                        "x-nvidia-router-model": model_id,
                        "x-nvidia-router-rpm": str(len(state.rpm_timestamps)),
                    },
                )
            else:
                resp_body = response.json()
                resp_body["model"] = f"nvidia-router/{model_id}"
                resp_body["nvidia_router"] = {
                    "model": model_id,
                    "status": model["status"],
                    "rpm": len(state.rpm_timestamps),
                }
                return JSONResponse(resp_body)

        # 429 — rate limited, try next model
        if status == 429:
            log.warning(f"Rate limited on {model_id}, rotating...")
            await state.mark_slow()
            await state.record_failure()
            tried += 1
            continue

        # Other error
        log.warning(f"Model {model_id} failed with {status}")
        await state.mark_slow()
        await state.record_failure()
        tried += 1

        if tried >= len(PRIMARY_MODELS):
            all_primary_failed = True
            break

    # All primary models failed — try fallbacks
    log.warning("All primary models failed, trying fallback models...")
    await state.reset_fallbacks()

    for _, fallback_start in enumerate(range(len(FALLBACK_MODELS))):
        fb_id = await state.get_next_fallback()
        if not fb_id:
            break

        log.info(f"Trying fallback: {fb_id}")
        status, error_body, response = await call_nvidia_model(
            fb_id, body, stream,
            timeout=REQUEST_SLOW_THRESHOLD * 2,
        )

        if status == 200 and response:
            elapsed = time.time() - start_time
            log.info(f"Fallback {fb_id} responded in {elapsed:.1f}s")
            if stream:
                return StreamingResponse(
                    generate_sse_stream(response, rpm_warning),
                    media_type="text/event-stream",
                    headers={
                        "x-nvidia-router-model": fb_id,
                        "x-nvidia-router-fallback": "true",
                    },
                )
            else:
                resp_body = response.json()
                resp_body["model"] = f"nvidia-router/{fb_id}"
                return JSONResponse(resp_body)

        if status == 429:
            log.warning(f"Fallback {fb_id} rate limited")
            continue

    # Everything failed — check RPM and report
    rpm = await state.rpm_current()
    error_msg = (
        f"Todos os modelos NVIDIA falharam. "
        f"({tried} modelos tentados). "
        f"RPM atual: {rpm}/{RPM_LIMIT} nos ultimos 60s. "
    )
    if rpm >= RPM_LIMIT * 0.5:
        error_msg += (
            f"Voce esta proximo do limite de {RPM_LIMIT} RPM. "
            f"Solicite upgrade para 200 RPM em https://build.nvidia.com ou aguarde ~60s."
        )

    return JSONResponse(
        {
            "error": error_msg,
            "nvidia_router": {
                "models_tried": tried,
                "all_failed": True,
                "rpm": rpm,
                "rpm_limit": RPM_LIMIT,
            },
        },
        status_code=503,
    )


async def status_page(request: Request):
    """GET /status — router diagnostics."""
    return JSONResponse(state.status_report())


async def health(request: Request):
    """GET /health — simple health check."""
    return JSONResponse({"status": "ok", "active_model": state.models[state.model_queue[state.active_idx]]["id"]})


# --- App ---

app = Starlette(
    routes=[
        Route("/v1/models", list_models, methods=["GET"]),
        Route("/v1/chat/completions", chat_completions, methods=["POST"]),
        Route("/status", status_page, methods=["GET"]),
        Route("/health", health, methods=["GET"]),
    ],
)


def main():
    import uvicorn
    import signal

    if not NVIDIA_API_KEY:
        log.warning("NVIDIA_API_KEY not set! The router will reject all requests.")
        log.warning("Set it with: $env:NVIDIA_API_KEY='nvapi-...'  (PowerShell)")
        log.warning("           or: set NVIDIA_API_KEY=nvapi-...     (CMD)")

    def shutdown_handler(signum, frame):
        log.info("Shutdown signal received. Stopping NVIDIA Router...")
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, shutdown_handler)
    signal.signal(signal.SIGINT, shutdown_handler)

    log.info(f"Starting NVIDIA Router on http://localhost:{PORT}")
    log.info(f"Primary models: {[m['id'] for m in PRIMARY_MODELS]}")
    log.info(f"Fallback models: {len(FALLBACK_MODELS)} available")
    log.info(f"RPM limit: {RPM_LIMIT} | Warning at: {int(RPM_LIMIT * RPM_WARN_FACTOR)}")
    log.info(f"Slow threshold: {CHUNK_SLOW_THRESHOLD}s chunk / {REQUEST_SLOW_THRESHOLD}s total")

    uvicorn.run(app, host="127.0.0.1", port=PORT, log_level="info", access_log=False)


if __name__ == "__main__":
    main()
