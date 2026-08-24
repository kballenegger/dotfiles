"""Sogni backend: argv/env construction and output collection.

Pure helpers so the argv layout is unit-testable; the worker owns the actual
subprocess. The flag layout mirrors the retired june-sogni MCP, which ran
these exact shapes in production against sogni-agent-hermes.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

KIND_EXTENSIONS = {"image": "png", "video": "mp4", "music": "mp3"}


def build_argv(params: dict, launcher: str, output_path: str) -> list[str]:
    argv = [
        launcher, "--json", "--quiet",
        "--output", output_path,
        "--quality", params["quality"],
        "--count", str(params["count"]),
    ]
    kind = params["kind"]
    if kind == "video":
        argv += ["--video", "--duration", str(params["duration_seconds"])]
    elif kind == "music":
        argv += ["--music", "--duration", str(params["duration_seconds"])]
    else:
        argv += ["--width", str(params["width"]), "--height", str(params["height"])]
    references = params.get("reference_images", [])
    if kind == "video" and references:
        # Video uses a first-frame reference. Passing image references through
        # --context changes Sogni's workflow and can silently lose identity.
        argv += ["--ref", references[0]]
    else:
        for reference in references:
            argv += ["--context", reference]
    if params.get("model"):
        argv += ["--model", params["model"]]
    if params.get("no_filter"):
        argv.append("--no-filter")
    argv.append(params["prompt"])
    return argv


def build_env(base_env: dict, workspace: str, credentials_path: str) -> dict:
    env = dict(base_env)
    env["HOME"] = workspace
    env["SOGNI_CREDENTIALS_PATH"] = credentials_path
    env["SOGNI_APP_ID_POOL_DIR"] = str(Path(workspace) / ".sogni-app-ids")
    env["SOGNI_LAST_RENDER_PATH"] = str(Path(workspace) / ".sogni-last-render.json")
    env["SOGNI_MODEL_CATALOG_CACHE_PATH"] = str(
        Path(workspace) / ".sogni-model-catalog.json"
    )
    return env


def collect_outputs(stdout: str, output_path: str) -> tuple[bool, list[str], str]:
    """Interpret a finished CLI run.

    Returns (success, output_files, error). Trusts the CLI's JSON payload
    when parseable, then verifies files on disk; with count > 1 the CLI
    derives sibling filenames from the requested output path, so the stem
    glob picks those up too.
    """
    payload: dict[str, Any] = {}
    error = ""
    try:
        payload = json.loads(stdout)
        if not isinstance(payload, dict):
            payload, error = {}, "Sogni returned non-object JSON."
    except (json.JSONDecodeError, TypeError):
        error = "Sogni returned invalid JSON."

    requested = Path(output_path)
    found: list[str] = []
    seen = set()

    output_root = requested.parent.resolve()

    def _add(path: Path) -> None:
        try:
            resolved = path.resolve(strict=True)
        except OSError:
            return
        if output_root not in resolved.parents:
            return
        key = str(resolved)
        if key not in seen and resolved.is_file():
            seen.add(key)
            found.append(key)

    for key in ("localPath", "localPaths", "files", "outputs"):
        value = payload.get(key)
        if isinstance(value, str):
            _add(Path(value))
        elif isinstance(value, list):
            for item in value:
                if isinstance(item, str):
                    _add(Path(item))
    _add(requested)
    for sibling in sorted(requested.parent.glob(requested.stem + "*")):
        _add(sibling)

    payload_error = payload.get("error")
    success = bool(payload.get("success", False)) and bool(found)
    if not success and not error:
        error = str(payload_error or "Sogni run produced no output files.")
    return success, found, error
