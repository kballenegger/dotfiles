"""Persistent MisoTTS HTTP service for lijiang (tailnet-only).

Loads the 8B MisoTTS model once at startup, caches voice prompts in GPU memory,
and exposes a tiny FastAPI surface compatible with the Dashboard ``audio-models``
card. Replaces Voicebox on the same tailnet port (17493).

Endpoints
---------
GET  /health                  service + GPU + model status
GET  /profiles                voicebox-shaped voice list (id/name/voice_type)
GET  /v1/audio/voices         base-TTS-shaped voice list (mapping)
POST /v1/audio/speech         OpenAI-shaped speech generation; returns WAV bytes
POST /generate                voicebox-shaped job kickoff; returns {id}
GET  /generate/{id}/status    voicebox-shaped SSE status stream
GET  /history/{id}/export-audio   raw WAV export for a completed generation

Concurrency model: a single asyncio.Lock + an `is_busy` flag — only one
generation runs at a time. Concurrent requests get HTTP 429.

Long-text behaviour: every request runs ``miso_chunker.chunk_text`` and
generates chunks sequentially, then stitches WAVs in memory. Chunk count
and timings are returned in response headers.

Run via systemd; see ``miso-tts.service``.
"""
from __future__ import annotations

import asyncio
import io
import os
import sys
import time
import uuid
import json
import logging
import struct
import threading
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional, List, Dict, Any

# ── Environment setup (must run before torch import) ────────────────────────
os.environ.setdefault("MISO_TTS_TOKENIZER_NAME", "unsloth/Llama-3.2-1B")
os.environ.setdefault("HF_HOME", "/home/kenneth/miso-tts/hf-cache")
os.environ.setdefault("HUGGINGFACE_HUB_CACHE", "/home/kenneth/miso-tts/hf-cache")
os.environ.setdefault("HSA_OVERRIDE_GFX_VERSION", "11.5.1")
os.environ.setdefault("NO_TORCH_COMPILE", "1")
sys.path.insert(0, "/home/kenneth/miso-tts/repo")
sys.path.insert(0, "/home/kenneth/miso-tts")

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse, Response, StreamingResponse
from pydantic import BaseModel, Field

# Local
from miso_chunker import chunk_text, Chunk  # noqa: E402

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
log = logging.getLogger("miso-tts")

# ── Voice references (Kenneth-controlled audio only) ────────────────────────
REF_KENNETH = "/home/kenneth/voicebox-data/profiles/c3229fcf-e125-444b-8cb5-9c6bbb858e20/12c27ae1-be90-444a-9075-88d1e32d390c.wav"
TR_KENNETH = (
    "Hey, check this out. I cloned my own voice using a model on my new machine, "
    "and now I can generate audio in my own voice without actually having to record it. "
    "Tell me if it sounds anything like me."
)
REF_ROSIE = "/home/kenneth/voice-sources/rosie/clips/strict_021.wav"
TR_ROSIE = (
    "I was like we're saying some stuff and I was like well, so do you want to listen to "
    "some of the because he out He asked me so I heard you're working on the album. "
    "How's it going? It's like that and I was like, well, do you want to have a listen? "
    "He's like wow I was like he was like Rosie's hot Damn it"
)
REF_SIRDAVID = "/home/kenneth/voice-sources/SirDavid/SirDavid_sample.wav"
TR_SIRDAVID = "In a colony numbering tens of thousands, a single grub is an insignificant loss."
VOICE_SPECS = {
    "baseline": {"speaker": 0, "ref": None,         "transcript": None, "display_name": "Baseline"},
    "kenneth":  {"speaker": 0, "ref": REF_KENNETH,  "transcript": TR_KENNETH, "display_name": "Kenneth"},
    "rosie":    {"speaker": 1, "ref": REF_ROSIE,    "transcript": TR_ROSIE, "display_name": "Rosie"},
    "sirdavid": {"speaker": 1, "ref": REF_SIRDAVID, "transcript": TR_SIRDAVID, "display_name": "Sir David"},
}

# Default generation budget per CHUNK (ms); the chunker keeps chunks ≤ ~30s
# of speech, so 35s is a comfortable ceiling.
DEFAULT_MAX_AUDIO_MS = 35_000


@dataclass
class _ModelState:
    generator: Any = None
    sample_rate: int = 24000
    device: str = "cpu"
    loaded_at: float = 0.0
    load_seconds: float = 0.0
    gpu_name: str = ""
    torch_version: str = ""
    hip_version: Optional[str] = None
    voices: Dict[str, Any] = field(default_factory=dict)


STATE = _ModelState()

# Single-flight lock for generation.
_GEN_LOCK = asyncio.Lock()
_BUSY: Dict[str, Any] = {"busy": False, "since": 0.0, "job_id": None, "text_len": 0}

# Completed jobs cache (for voicebox-compatible /history/{id}/export-audio).
_JOBS: Dict[str, Dict[str, Any]] = {}
_JOBS_LOCK = threading.Lock()
_JOBS_MAX = 20  # keep most-recent N audio buffers in memory


def _load_prompt(path: str, sample_rate: int):
    import soundfile as sf
    import torch
    import torchaudio
    arr, orig_sr = sf.read(path, dtype="float32", always_2d=False)
    if arr.ndim == 2:
        arr = arr.mean(axis=1)
    audio = torch.from_numpy(arr)
    if orig_sr != sample_rate:
        audio = torchaudio.functional.resample(audio, orig_freq=orig_sr, new_freq=sample_rate)
    return audio


def _bootstrap_model() -> None:
    """Cold-load the model and prebuild voice contexts. Blocking; call once."""
    import torch
    import load_patch
    load_patch.install()
    from generator import load_miso_8b, Segment

    t0 = time.time()
    device = "cuda" if torch.cuda.is_available() else "cpu"
    log.info("loading miso 8b on %s", device)
    gen = load_miso_8b(device=device)
    load_secs = time.time() - t0
    STATE.generator = gen
    STATE.sample_rate = gen.sample_rate
    STATE.device = device
    STATE.loaded_at = time.time()
    STATE.load_seconds = load_secs
    STATE.torch_version = torch.__version__
    STATE.hip_version = getattr(torch.version, "hip", None)
    STATE.gpu_name = torch.cuda.get_device_name(0) if torch.cuda.is_available() else ""

    voices: Dict[str, Any] = {}
    for name, spec in VOICE_SPECS.items():
        ctx: List[Any] = []
        if spec["ref"]:
            try:
                audio = _load_prompt(spec["ref"], STATE.sample_rate)
                ctx = [Segment(speaker=spec["speaker"], text=spec["transcript"], audio=audio)]
                log.info("loaded prompt %s (%.2fs of audio)", name, audio.shape[0] / STATE.sample_rate)
            except Exception as e:
                log.warning("voice %s prompt load failed: %s", name, e)
        voices[name] = {
            "speaker": spec["speaker"],
            "context": ctx,
            "has_ref": bool(spec["ref"]),
        }
    STATE.voices = voices
    log.info("model ready in %.1fs sample_rate=%d voices=%s", load_secs, STATE.sample_rate, list(voices))


def _generate_chunk_sync(text: str, voice: str, max_audio_ms: int, temperature: float, topk: int, seed: Optional[int]):
    """Generate audio for a single chunk. Caller must hold _GEN_LOCK."""
    import torch
    v = STATE.voices[voice]
    if seed is not None:
        torch.manual_seed(int(seed))
    audio = STATE.generator.generate(
        text=text,
        speaker=v["speaker"],
        context=v["context"],
        max_audio_length_ms=max_audio_ms,
        temperature=float(temperature),
        topk=int(topk),
    )
    # Return float32 numpy 1D
    arr = audio.detach().cpu().numpy()
    if arr.ndim == 2:
        arr = arr.squeeze(0)
    return arr


def _wav_bytes(samples_f32, sample_rate: int) -> bytes:
    """Encode a float32 mono numpy array to 16-bit PCM WAV bytes."""
    import numpy as np
    pcm = np.clip(samples_f32, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2").tobytes()
    n_samples = len(pcm) // 2
    byte_rate = sample_rate * 2
    block_align = 2
    data_size = len(pcm)
    fmt_chunk = struct.pack("<4sI HHIIHH",
        b"fmt ", 16, 1, 1, sample_rate, byte_rate, block_align, 16)
    data_chunk = struct.pack("<4sI", b"data", data_size) + pcm
    riff = struct.pack("<4sI4s", b"RIFF", 4 + len(fmt_chunk) + len(data_chunk), b"WAVE")
    return riff + fmt_chunk + data_chunk


def _generate_full_sync(text: str, voice: str, *, max_audio_ms: int, temperature: float,
                         topk: int, seed: Optional[int], target_chars: int) -> Dict[str, Any]:
    """Chunk + generate + stitch. Returns {wav_bytes, manifest, sample_rate}."""
    import numpy as np
    chunks = chunk_text(text, target_chars=target_chars)
    if not chunks:
        raise ValueError("empty text")
    log.info("generation start voice=%s chunks=%d total_chars=%d", voice, len(chunks), sum(len(c.text) for c in chunks))
    audio_parts: List[Any] = []
    manifest: List[Dict[str, Any]] = []
    for c in chunks:
        t0 = time.time()
        arr = _generate_chunk_sync(c.text, voice, max_audio_ms, temperature, topk, seed)
        dt = time.time() - t0
        dur = len(arr) / STATE.sample_rate
        audio_parts.append(arr)
        manifest.append({
            "index": c.index, "chars": len(c.text), "break_kind": c.break_kind,
            "gen_seconds": round(dt, 2), "audio_seconds": round(dur, 2),
            "rtf": round(dt / dur, 2) if dur > 0 else None,
        })
        log.info("  chunk %d/%d kind=%s chars=%d gen=%.1fs dur=%.1fs rtf=%.2f",
                 c.index + 1, len(chunks), c.break_kind, len(c.text), dt, dur,
                 dt / dur if dur > 0 else 0.0)
    # Stitch with a short silence between chunks (50 ms) so paragraph breaks
    # have a natural beat rather than a hard splice.
    silence = np.zeros(int(STATE.sample_rate * 0.05), dtype="float32")
    out = audio_parts[0]
    for part in audio_parts[1:]:
        out = np.concatenate([out, silence, part])
    wav = _wav_bytes(out, STATE.sample_rate)
    total_audio = len(out) / STATE.sample_rate
    total_gen = sum(m["gen_seconds"] for m in manifest)
    log.info("generation done chunks=%d gen_s=%.1f audio_s=%.1f rtf=%.2f size=%d",
             len(chunks), total_gen, total_audio, total_gen / total_audio if total_audio > 0 else 0, len(wav))
    return {
        "wav": wav,
        "manifest": manifest,
        "sample_rate": STATE.sample_rate,
        "total_audio_s": round(total_audio, 2),
        "total_gen_s": round(total_gen, 2),
        "chunk_count": len(chunks),
    }


def _remember_job(job_id: str, payload: Dict[str, Any]) -> None:
    with _JOBS_LOCK:
        _JOBS[job_id] = payload
        # Trim oldest jobs to bound memory.
        if len(_JOBS) > _JOBS_MAX:
            for k in list(_JOBS.keys())[:-_JOBS_MAX]:
                _JOBS.pop(k, None)


def _set_busy(job_id: Optional[str], text_len: int) -> None:
    _BUSY["busy"] = True
    _BUSY["since"] = time.time()
    _BUSY["job_id"] = job_id
    _BUSY["text_len"] = text_len


def _clear_busy() -> None:
    _BUSY["busy"] = False
    _BUSY["since"] = 0.0
    _BUSY["job_id"] = None
    _BUSY["text_len"] = 0


# ── FastAPI app ─────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(_app: FastAPI):
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, _bootstrap_model)
    yield


app = FastAPI(title="miso-tts", lifespan=lifespan)


class SpeechRequest(BaseModel):
    input: str
    voice: Optional[str] = "rosie"
    response_format: Optional[str] = "wav"
    language: Optional[str] = "en"
    instructions: Optional[str] = None
    max_audio_ms: Optional[int] = None
    target_chars: Optional[int] = None
    temperature: Optional[float] = 0.9
    top_k: Optional[int] = 50
    seed: Optional[int] = None
    model: Optional[str] = None


class GenerateRequest(BaseModel):
    profile_id: Optional[str] = None
    profile: Optional[str] = None
    voice: Optional[str] = None
    text: str
    engine: Optional[str] = None
    max_audio_ms: Optional[int] = None
    target_chars: Optional[int] = None
    temperature: Optional[float] = 0.9
    top_k: Optional[int] = 50
    seed: Optional[int] = None


def _resolve_voice(name: Optional[str]) -> str:
    n = (name or "rosie").strip().lower()
    if n in VOICE_SPECS:
        return n
    # Voicebox profile names (case-sensitive in their world) → canonical lowercase.
    if n in {"rosie", "kenneth", "baseline"}:
        return n
    if n in {"sir_david", "sir-david", "sir david"}:
        return "sirdavid"
    raise HTTPException(status_code=400, detail=f"unknown voice {name!r}, available: {list(VOICE_SPECS)}")


def _validate_loaded() -> None:
    if STATE.generator is None:
        raise HTTPException(status_code=503, detail="model not loaded yet")


@app.get("/health")
async def health():
    gpu_free_gb = None
    gpu_total_gb = None
    if STATE.generator is not None:
        try:
            import torch
            if torch.cuda.is_available():
                free, total = torch.cuda.mem_get_info()
                gpu_free_gb = round(free / 1e9, 2)
                gpu_total_gb = round(total / 1e9, 2)
        except Exception:
            pass
    healthy = STATE.generator is not None and not _BUSY["busy"]
    payload = {
        "service": "miso-tts",
        "status": "healthy" if healthy else ("busy" if _BUSY["busy"] else "loading"),
        "model_loaded": STATE.generator is not None,
        "device": STATE.device,
        "gpu_available": STATE.device == "cuda",
        "gpu_type": STATE.gpu_name,
        "torch_version": STATE.torch_version,
        "hip_version": STATE.hip_version,
        "sample_rate": STATE.sample_rate,
        "voices": list(STATE.voices.keys()),
        "busy": _BUSY["busy"],
        "busy_since": _BUSY["since"],
        "busy_text_len": _BUSY["text_len"],
        "loaded_at": STATE.loaded_at,
        "load_seconds": STATE.load_seconds,
        "gpu_free_gb": gpu_free_gb,
        "gpu_total_gb": gpu_total_gb,
        "model_repo": "MisoLabs/MisoTTS",
        "watermark": "silentcipher-default-key",
        "concurrency": "single-flight (one generation at a time)",
    }
    return payload


@app.get("/profiles")
async def profiles():
    # Voicebox-shaped: list of {id, name, voice_type, default_engine, language}
    out = []
    for name in VOICE_SPECS:
        out.append({
            "id": name,
            "name": VOICE_SPECS[name].get("display_name", name.capitalize()),
            "voice_type": "cloned" if VOICE_SPECS[name]["ref"] else "baseline",
            "default_engine": "miso-tts-8b",
            "language": "en",
        })
    return out


@app.get("/v1/audio/voices")
async def voices_list():
    # Base-TTS-shaped: {model: [voice_id, ...]}
    return {"miso-tts-8b": list(VOICE_SPECS.keys())}


@app.get("/v1/audio/languages")
async def languages_list():
    return ["en"]


def _run_generation_locked(text: str, voice: str, *, max_audio_ms: int, temperature: float,
                             topk: int, seed: Optional[int], target_chars: int, job_id: str):
    """Run in a worker thread under the asyncio lock."""
    try:
        _set_busy(job_id, len(text))
        result = _generate_full_sync(
            text=text, voice=voice, max_audio_ms=max_audio_ms,
            temperature=temperature, topk=topk, seed=seed, target_chars=target_chars,
        )
        _remember_job(job_id, {
            "status": "completed",
            "voice": voice,
            "wav": result["wav"],
            "sample_rate": result["sample_rate"],
            "manifest": result["manifest"],
            "total_audio_s": result["total_audio_s"],
            "total_gen_s": result["total_gen_s"],
            "chunk_count": result["chunk_count"],
            "completed_at": time.time(),
        })
        return result
    finally:
        _clear_busy()


@app.post("/v1/audio/speech")
async def speech(req: SpeechRequest, request: Request):
    _validate_loaded()
    if not req.input or not req.input.strip():
        raise HTTPException(status_code=400, detail="input required")
    if req.response_format and req.response_format.lower() not in {"wav"}:
        raise HTTPException(status_code=400, detail=f"only wav is supported, got {req.response_format}")
    voice = _resolve_voice(req.voice)
    max_audio_ms = int(req.max_audio_ms or DEFAULT_MAX_AUDIO_MS)
    target_chars = int(req.target_chars or 380)
    temperature = float(req.temperature if req.temperature is not None else 0.9)
    topk = int(req.top_k or 50)
    seed = req.seed if req.seed is not None else None

    if _BUSY["busy"]:
        return JSONResponse(status_code=429, content={
            "error": "miso-tts is busy with another generation",
            "busy_since": _BUSY["since"],
            "busy_text_len": _BUSY["text_len"],
        })

    job_id = f"job_{int(time.time())}_{uuid.uuid4().hex[:8]}"
    loop = asyncio.get_event_loop()
    async with _GEN_LOCK:
        try:
            result = await loop.run_in_executor(
                None,
                lambda: _run_generation_locked(
                    req.input, voice, max_audio_ms=max_audio_ms,
                    temperature=temperature, topk=topk, seed=seed,
                    target_chars=target_chars, job_id=job_id,
                ),
            )
        except HTTPException:
            raise
        except Exception as e:
            log.exception("generation failed")
            return JSONResponse(status_code=500, content={
                "error": f"generation failed: {type(e).__name__}: {e}",
                "job_id": job_id,
            })
    headers = {
        "X-Miso-Job-Id": job_id,
        "X-Miso-Voice": voice,
        "X-Miso-Chunks": str(result["chunk_count"]),
        "X-Miso-Audio-Seconds": str(result["total_audio_s"]),
        "X-Miso-Gen-Seconds": str(result["total_gen_s"]),
        "X-Miso-Sample-Rate": str(result["sample_rate"]),
    }
    return Response(content=result["wav"], media_type="audio/wav", headers=headers)


@app.post("/generate")
async def generate(req: GenerateRequest):
    """Voicebox-style job kickoff: returns {id} immediately and runs in background."""
    _validate_loaded()
    if not req.text or not req.text.strip():
        raise HTTPException(status_code=400, detail="text required")
    voice = _resolve_voice(req.profile_id or req.profile or req.voice)
    max_audio_ms = int(req.max_audio_ms or DEFAULT_MAX_AUDIO_MS)
    target_chars = int(req.target_chars or 380)
    temperature = float(req.temperature if req.temperature is not None else 0.9)
    topk = int(req.top_k or 50)
    seed = req.seed if req.seed is not None else None

    if _BUSY["busy"]:
        raise HTTPException(status_code=429, detail="miso-tts is busy")

    job_id = f"job_{int(time.time())}_{uuid.uuid4().hex[:8]}"
    _remember_job(job_id, {
        "status": "queued",
        "voice": voice,
        "wav": None,
        "manifest": [],
        "created_at": time.time(),
    })

    async def _runner():
        loop = asyncio.get_event_loop()
        async with _GEN_LOCK:
            try:
                await loop.run_in_executor(
                    None,
                    lambda: _run_generation_locked(
                        req.text, voice, max_audio_ms=max_audio_ms,
                        temperature=temperature, topk=topk, seed=seed,
                        target_chars=target_chars, job_id=job_id,
                    ),
                )
            except Exception as e:
                log.exception("background generation failed")
                _remember_job(job_id, {
                    "status": "failed",
                    "error": f"{type(e).__name__}: {e}",
                    "voice": voice,
                    "wav": None,
                    "completed_at": time.time(),
                })

    asyncio.create_task(_runner())
    return {"id": job_id, "generation_id": job_id, "status": "running"}


@app.get("/generate/{job_id}/status")
async def generate_status(job_id: str):
    """Server-Sent Events stream that ends when the job is terminal."""
    async def events():
        # Initial event: current state.
        last_status = None
        while True:
            job = _JOBS.get(job_id)
            if not job:
                # Not yet recorded — emit a placeholder and wait.
                payload = {"status": "queued", "id": job_id}
            else:
                payload = {
                    "status": job.get("status", "running"),
                    "id": job_id,
                    "voice": job.get("voice"),
                    "chunk_count": job.get("chunk_count"),
                    "total_audio_s": job.get("total_audio_s"),
                    "total_gen_s": job.get("total_gen_s"),
                    "manifest_summary": [
                        {"index": m["index"], "break_kind": m["break_kind"], "audio_seconds": m["audio_seconds"]}
                        for m in job.get("manifest", [])
                    ] if job.get("manifest") else [],
                }
                if job.get("error"):
                    payload["error"] = job["error"]
            yield f"data: {json.dumps(payload)}\n\n"
            if payload["status"] in {"completed", "failed", "cancelled", "error"}:
                return
            last_status = payload["status"]
            await asyncio.sleep(2.0)

    return StreamingResponse(events(), media_type="text/event-stream")


@app.get("/history/{job_id}/export-audio")
async def export_audio(job_id: str):
    job = _JOBS.get(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="job not found")
    if job.get("status") != "completed":
        raise HTTPException(status_code=409, detail=f"job not complete: {job.get('status')}")
    wav = job.get("wav")
    if not wav:
        raise HTTPException(status_code=500, detail="job has no audio buffer")
    return Response(content=wav, media_type="audio/wav")


@app.post("/shutdown")
async def shutdown():
    log.info("shutdown requested")
    asyncio.get_event_loop().call_later(0.5, lambda: os._exit(0))
    return {"status": "shutting down"}


def main():
    import uvicorn
    host = os.environ.get("MISO_TTS_HOST", "100.99.209.82")
    port = int(os.environ.get("MISO_TTS_PORT", "17493"))
    log.info("starting miso-tts on %s:%d", host, port)
    uvicorn.run("server:app", host=host, port=port, log_level="info", access_log=False)


if __name__ == "__main__":
    main()
