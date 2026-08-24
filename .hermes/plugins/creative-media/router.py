"""Request validation, normalization, and dedupe hashing.

Pure functions, stdlib only, no I/O beyond reference-image stat/hash. Every
create_media request passes through :func:`normalize_request` before a job row
is created; the returned dict is the canonical params_json stored on the job
and consumed by the worker.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from .settings import IMAGE_SUFFIXES

PROVIDERS = ("gpt-image", "sogni")
KINDS = ("image", "video", "music")
QUALITIES = ("fast", "hq", "pro")
ASPECT_RATIOS = ("square", "landscape", "portrait")

# aspect_ratio -> (width, height) for Sogni, which takes explicit pixels.
SOGNI_ASPECT_DIMS = {
    "square": (1024, 1024),
    "landscape": (1344, 768),
    "portrait": (768, 1344),
}

MAX_PROMPT_CHARS = 12000
MAX_REFS = {"gpt-image": 16, "sogni": 4}
MODEL_CHARSET = set(
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-"
)


class ValidationError(ValueError):
    """Raised for any request the tool surface must reject."""


def _require_int(value: Any, name: str, lo: int, hi: int, default: int) -> int:
    if value is None:
        return default
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValidationError(f"{name} must be an integer between {lo} and {hi}.")
    if not lo <= value <= hi:
        raise ValidationError(f"{name} must be between {lo} and {hi}.")
    return value


def validate_workspace_images(
    reference_images: Any, workspace: Path, maximum: int
) -> list[str]:
    """Return resolved reference paths, all strictly inside *workspace*.

    Symlinks are resolved before the containment check, so a link that
    escapes the workspace is rejected even though the link itself lives
    inside it.
    """
    if reference_images is None:
        return []
    if not isinstance(reference_images, list) or len(reference_images) > maximum:
        raise ValidationError(
            f"reference_images must be a list of at most {maximum} "
            f"workspace image paths."
        )
    workspace = workspace.resolve()
    validated: list[str] = []
    for item in reference_images:
        if not isinstance(item, str) or not item.strip():
            raise ValidationError("Each reference image must be a non-empty path.")
        try:
            path = Path(item).expanduser().resolve(strict=True)
        except OSError:
            raise ValidationError(f"Reference image does not exist: {item}")
        if workspace not in path.parents or not path.is_file():
            raise ValidationError(
                f"Reference images must be regular files inside {workspace}."
            )
        if path.suffix.lower() not in IMAGE_SUFFIXES:
            raise ValidationError(
                "Reference images must be supported image files "
                f"({', '.join(sorted(IMAGE_SUFFIXES))})."
            )
        validated.append(str(path))
    return validated


def normalize_request(args: dict, workspace: Path) -> dict:
    """Validate a raw create_media call and return canonical job params."""
    prompt = args.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip():
        raise ValidationError("prompt is required.")
    prompt = prompt.strip()
    if len(prompt) > MAX_PROMPT_CHARS:
        raise ValidationError(f"prompt must be at most {MAX_PROMPT_CHARS} characters.")

    provider = args.get("provider")
    if provider not in PROVIDERS:
        raise ValidationError(f"provider must be one of {', '.join(PROVIDERS)}.")

    kind = args.get("kind") or "image"
    if kind not in KINDS:
        raise ValidationError(f"kind must be one of {', '.join(KINDS)}.")
    if provider == "gpt-image" and kind != "image":
        raise ValidationError(
            "gpt-image only supports kind='image'. Use provider='sogni' for "
            "video and music."
        )

    aspect_ratio = args.get("aspect_ratio") or "square"
    if aspect_ratio not in ASPECT_RATIOS:
        raise ValidationError(
            f"aspect_ratio must be one of {', '.join(ASPECT_RATIOS)}."
        )

    quality = args.get("quality") or "fast"
    if quality not in QUALITIES:
        raise ValidationError(f"quality must be one of {', '.join(QUALITIES)}.")

    model = args.get("model") or ""
    if model:
        if not isinstance(model, str) or len(model) > 120 or any(
            ch not in MODEL_CHARSET for ch in model
        ):
            raise ValidationError("model contains unsupported characters.")
    if provider == "gpt-image" and model:
        raise ValidationError("model is only supported with provider='sogni'.")

    no_filter = args.get("no_filter", False)
    if not isinstance(no_filter, bool):
        raise ValidationError("no_filter must be true or false.")
    if no_filter and provider != "sogni":
        raise ValidationError("no_filter is only supported with provider='sogni'.")

    default_w, default_h = SOGNI_ASPECT_DIMS[aspect_ratio]
    width = _require_int(args.get("width"), "width", 512, 2048, default_w)
    height = _require_int(args.get("height"), "height", 512, 2048, default_h)
    count = _require_int(args.get("count"), "count", 1, 4, 1)
    duration_seconds = _require_int(
        args.get("duration_seconds"), "duration_seconds", 3, 30, 5
    )

    references = validate_workspace_images(
        args.get("reference_images"), workspace, MAX_REFS[provider]
    )

    idempotency_key = args.get("idempotency_key") or ""
    if idempotency_key and (
        not isinstance(idempotency_key, str) or len(idempotency_key) > 200
    ):
        raise ValidationError("idempotency_key must be a short string.")

    params = {
        "prompt": prompt,
        "provider": provider,
        "kind": kind,
        "aspect_ratio": aspect_ratio,
        "quality": quality,
        "model": model,
        "width": width,
        "height": height,
        "count": count,
        "duration_seconds": duration_seconds,
        "reference_images": references,
        "no_filter": no_filter,
        "idempotency_key": idempotency_key,
    }
    return params


def _hash_file(path: str) -> str:
    h = hashlib.sha256()
    try:
        with open(path, "rb") as fh:
            for chunk in iter(lambda: fh.read(1 << 20), b""):
                h.update(chunk)
    except OSError:
        # Content unavailable — fall back to the path so the hash stays stable.
        h.update(path.encode())
    return h.hexdigest()


def dedupe_hash(params: dict) -> str:
    """Stable hash identifying a generation request.

    An explicit idempotency_key replaces the parameter fingerprint entirely
    (still namespaced by provider+kind), so a caller can force dedupe across
    prompt tweaks or force uniqueness for identical prompts.
    """
    if params.get("idempotency_key"):
        basis: Any = {
            "provider": params["provider"],
            "kind": params["kind"],
            "idempotency_key": params["idempotency_key"],
        }
    else:
        basis = {
            k: params[k]
            for k in (
                "prompt", "provider", "kind", "aspect_ratio", "quality",
                "model", "width", "height", "count", "duration_seconds",
                "no_filter",
            )
        }
        basis["reference_images"] = sorted(
            _hash_file(p) for p in params.get("reference_images", [])
        )
    blob = json.dumps(basis, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(blob.encode()).hexdigest()
