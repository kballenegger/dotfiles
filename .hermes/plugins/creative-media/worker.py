#!/usr/bin/env python3
"""Detached generation worker for the creative-media plugin.

Spawned by create_media as its own session leader
(``start_new_session=True``), so a gateway or agent-process restart does not
kill an in-flight render. All coordination goes through the SQLite job store;
this process never talks to Hermes.

Usage:
    python3 worker.py --db /path/jobs.db --events /path/jobs.log.jsonl \
        --job jm-xxxx --workspace /Users/incognito \
        [--launcher /opt/homebrew/bin/sogni-agent-hermes] \
        [--credentials /path/credentials] [--klaw-lib /path/klaw-workspace]

Exit codes: 0 job reached a terminal state and was recorded; 1 unrecoverable
setup error (also recorded on the job row when possible).
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import signal
import subprocess
import sys
import threading
import time
import uuid
from pathlib import Path

PLUGIN_DIR = Path(__file__).resolve().parent
_PKG = "creative_media_worker"


def _load_pkg():
    """Import the plugin as a package so relative imports work standalone."""
    if _PKG in sys.modules:
        return sys.modules[_PKG]
    spec = importlib.util.spec_from_file_location(
        _PKG, PLUGIN_DIR / "__init__.py",
        submodule_search_locations=[str(PLUGIN_DIR)],
    )
    module = importlib.util.module_from_spec(spec)
    sys.modules[_PKG] = module
    spec.loader.exec_module(module)
    return module


_load_pkg()
settings = importlib.import_module(f"{_PKG}.settings")
jobs_mod = importlib.import_module(f"{_PKG}.jobs")
sogni = importlib.import_module(f"{_PKG}.providers.sogni")
gpt_image = importlib.import_module(f"{_PKG}.providers.gpt_image")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", required=True)
    parser.add_argument("--events", required=True)
    parser.add_argument("--job", required=True)
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--launcher", default=settings.DEFAULT_SOGNI_LAUNCHER)
    parser.add_argument("--credentials", default=settings.DEFAULT_SOGNI_CREDENTIALS)
    parser.add_argument("--klaw-lib", default=settings.DEFAULT_KLAW_WORKSPACE_LIB)
    args = parser.parse_args()

    store = jobs_mod.JobStore(args.db, args.events)
    job = store.get(args.job)
    if job is None:
        print(f"unknown job {args.job}", file=sys.stderr)
        return 1
    if job["state"] not in ("queued", "running"):
        return 0  # canceled before we started, or a duplicate spawn

    params = json.loads(job["params_json"])
    workspace = Path(args.workspace).resolve()
    store.mark_running(args.job, os.getpid())

    # Heartbeat so status readers can tell a live worker from a dead one.
    stop_heartbeat = threading.Event()

    def _beat() -> None:
        while not stop_heartbeat.wait(5):
            try:
                store.heartbeat(args.job)
            except Exception:
                pass

    threading.Thread(target=_beat, daemon=True).start()

    def _on_sigterm(_sig, _frame):
        try:
            store.mark_canceled(args.job, "canceled (worker received SIGTERM)")
        finally:
            os._exit(0)

    signal.signal(signal.SIGTERM, _on_sigterm)

    provider = params["provider"]
    kind = params["kind"]
    subdir = (
        settings.GPT_OUTPUT_SUBDIR if provider == "gpt-image"
        else settings.SOGNI_OUTPUT_SUBDIR
    )
    out_dir = workspace / subdir
    out_dir.mkdir(parents=True, exist_ok=True)
    extension = sogni.KIND_EXTENSIONS[kind]
    output_path = (out_dir / f"render-{uuid.uuid4().hex}.{extension}").resolve()
    if out_dir.resolve() not in output_path.parents:
        store.mark_failed(args.job, "refused an output path outside the workspace")
        return 0

    try:
        if provider == "gpt-image":
            success, outputs, error = gpt_image.run(
                params, str(output_path), args.klaw_lib
            )
        else:
            success, outputs, error = _run_sogni(
                store, args.job, params, args.launcher, args.credentials,
                str(workspace), str(output_path),
            )
    except Exception as exc:  # never leave a job stuck in running
        store.mark_failed(args.job, f"worker crashed: {exc}")
        return 0

    stop_heartbeat.set()
    current = store.get(args.job)
    if current and current["state"] == "canceled":
        return 0  # cancel won the race; don't overwrite it
    if success:
        store.mark_done(args.job, outputs)
    else:
        store.mark_failed(args.job, error or "generation failed")
    return 0


def _validate_live_sogni_model(params, launcher, env) -> str:
    """Reject a stale or incompatible explicit model before a paid render.

    The Sogni catalog changes independently of Hermes. Only exact model IDs
    returned by the live catalog for the requested media kind are accepted.
    An omitted model lets Sogni choose its current compatible default.
    """
    model = params.get("model")
    if not model:
        return ""
    try:
        probe = subprocess.run(
            [launcher, "--search-models", model, "--model-media", params["kind"],
             "--json", "--quiet"],
            capture_output=True, text=True, timeout=30, env=env, check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return f"could not verify Sogni model '{model}' against the live catalog: {exc}"
    payload = None
    for line in probe.stdout.splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict) and value.get("type") == "live-models":
            payload = value
            break
    models = payload.get("models", []) if isinstance(payload, dict) else []
    if not any(isinstance(item, dict) and item.get("id") == model for item in models):
        return (
            f"Sogni model '{model}' is not available for {params['kind']} in the "
            "live catalog. Omit model to use Sogni's compatible default, or supply "
            "an exact ID from the live catalog."
        )
    return ""


def _run_sogni(store, job_id, params, launcher, credentials, workspace, output_path):
    env = sogni.build_env(os.environ, workspace, credentials)
    model_error = _validate_live_sogni_model(params, launcher, env)
    if model_error:
        return False, [], model_error
    argv = sogni.build_argv(params, launcher, output_path)
    timeout = settings.KIND_TIMEOUTS[params["kind"]]
    store.log_event(job_id, "sogni_exec", timeout=timeout)
    try:
        result = subprocess.run(
            argv, capture_output=True, text=True, timeout=timeout,
            env=env, check=False,
        )
    except subprocess.TimeoutExpired:
        return False, [], f"Sogni run exceeded the {timeout}s limit and was stopped."
    success, outputs, error = sogni.collect_outputs(result.stdout, output_path)
    if not success and result.returncode != 0 and result.stderr:
        error = f"{error} (exit {result.returncode}: {result.stderr.strip()[:300]})"
    return success, outputs, error


if __name__ == "__main__":
    sys.exit(main())
