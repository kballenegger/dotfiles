#!/usr/bin/env python3
"""tmux-resurrect post-save-layout hook: make Claude Code panes resumable.

Resurrect saves each pane's command line as typed, so a pane running plain
`claude` would come back as a *new* session. For every pane with a Claude Code
process underneath it, look the process up in ~/.claude/sessions/<pid>.json
(Claude Code's live-session registry) and rewrite the saved command to
`cd <session cwd> && claude --resume <session id>`. The matching
@resurrect-processes entry ("~claude --resume") then relaunches it on restore.

Invoked by resurrect with the save file path as the only argument.
"""
import json
import os
import shlex
import subprocess
import sys

SESSIONS_DIR = os.path.expanduser("~/.claude/sessions")
MAX_DEPTH = 3  # pane shell -> claude (-> wrapper) is as deep as it gets


def children(pid):
    out = subprocess.run(["pgrep", "-P", str(pid)], capture_output=True, text=True).stdout
    return [int(p) for p in out.split()]


def claude_session(pid, depth=0):
    try:
        with open(os.path.join(SESSIONS_DIR, f"{pid}.json")) as f:
            s = json.load(f)
        if s.get("sessionId") and s.get("kind", "interactive") == "interactive":
            return s
    except (OSError, ValueError):
        pass
    if depth >= MAX_DEPTH:
        return None
    for child in children(pid):
        s = claude_session(child, depth + 1)
        if s:
            return s
    return None


def pane_pid(session, window, pane):
    out = subprocess.run(
        ["tmux", "display-message", "-p", "-t", f"={session}:{window}.{pane}", "#{pane_pid}"],
        capture_output=True, text=True,
    ).stdout.strip()
    return int(out) if out.isdigit() else None


def main(path):
    with open(path) as f:
        lines = f.read().split("\n")
    changed = False
    for i, line in enumerate(lines):
        # pane <session> <window> <win_active> :<flags> <pane_idx> <title> :<dir> <active> <cmd> :<full_cmd>
        fields = line.split("\t")
        if fields[0] != "pane" or len(fields) < 11:
            continue
        pid = pane_pid(fields[1], fields[2], fields[5])
        s = pid and claude_session(pid)
        if not s:
            continue
        cmd = f"claude --resume {s['sessionId']}"
        if s.get("cwd"):
            cmd = f"cd {shlex.quote(s['cwd'])} && {cmd}"
        fields[10] = ":" + cmd
        lines[i] = "\t".join(fields)
        changed = True
    if changed:
        with open(path, "w") as f:
            f.write("\n".join(lines))


if __name__ == "__main__":
    main(sys.argv[1])
