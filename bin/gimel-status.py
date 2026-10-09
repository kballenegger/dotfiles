#!/usr/bin/env python3
"""gimel-status — tiny read-only health API for monitors, served on :8090.

macOS port of astana-status.py (same JSON shape, so the Klaw dashboard's
klaw-host card can consume it as an "http" target).

GET /status  -> JSON: services, load, cpu%, memory, swap, disk, gpu
GET /healthz -> 200 "ok" (liveness only)

stdlib only (Apple's /usr/bin/python3 is enough); no auth. Binds loopback plus
the Tailscale (CGNAT 100.64/10) address only, never the LAN, and waits for the
Tailscale interface to appear after boot.
"""
import ctypes
import ctypes.util
import json
import re
import shutil
import socket
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = 8090
PROCESSES = {"herdr-server": ("herdr", "server"), "klawhealth": ("KlawHealth", None)}
PORTS = {
    "feke": 42040,
    "klawhealth": 8765,
    "postgres": 5432,
    "mongod": 27017,
    "ollama": 11434,
    "ornith_mlx": 11440,
}
HOST = socket.gethostname().split(".")[0]


def run(args, timeout=3):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout).stdout
    except Exception:
        return ""


def sysctl(name):
    return run(["/usr/sbin/sysctl", "-n", name]).strip()


# ── CPU via mach host_statistics (no /proc on macOS) ────────────────────────
_libc = None


class _CpuLoadInfo(ctypes.Structure):
    _fields_ = [("ticks", ctypes.c_uint32 * 4)]  # user, system, idle, nice


def cpu_sample():
    global _libc
    if _libc is None:
        _libc = ctypes.CDLL(ctypes.util.find_library("System") or "/usr/lib/libSystem.dylib")
        _libc.mach_host_self.restype = ctypes.c_uint32
    info = _CpuLoadInfo()
    count = ctypes.c_uint32(4)
    rc = _libc.host_statistics(_libc.mach_host_self(), 3, ctypes.byref(info), ctypes.byref(count))
    if rc != 0:
        raise OSError("host_statistics failed: %d" % rc)
    t = list(info.ticks)
    return t[2], sum(t)


def cpu_percent():
    try:
        i1, t1 = cpu_sample()
        time.sleep(0.25)
        i2, t2 = cpu_sample()
    except Exception:
        return None
    dt = t2 - t1
    return round(100 * (1 - (i2 - i1) / dt), 1) if dt else None


# ── Memory: Activity Monitor's "Memory Used" = app (anon - purgeable) + wired + compressed
def meminfo():
    total = int(sysctl("hw.memsize") or 0)
    vm = run(["/usr/bin/vm_stat"])
    page = 16384
    m = re.search(r"page size of (\d+)", vm)
    if m:
        page = int(m.group(1))
    kv = {}
    for line in vm.splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            v = v.strip().rstrip(".")
            if v.isdigit():
                kv[k.strip().strip('"')] = int(v)
    used_pages = (
        kv.get("Anonymous pages", 0)
        - kv.get("Pages purgeable", 0)
        + kv.get("Pages wired down", 0)
        + kv.get("Pages occupied by compressor", 0)
    )
    used = max(0, used_pages * page)
    swap_used = 0.0
    m = re.search(r"used = ([\d.]+)([KMG])", sysctl("vm.swapusage"))
    if m:
        swap_used = float(m.group(1)) / {"K": 1048576, "M": 1024, "G": 1}[m.group(2)]
    gb = lambda b: round(b / 2**30, 1)
    return {
        "total_gb": gb(total),
        "available_gb": gb(max(0, total - used)),
        "used_pct": round(100 * used / total, 1) if total else None,
        "swap_used_gb": round(swap_used, 1),
    }


def uptime_s():
    m = re.search(r"sec = (\d+)", sysctl("kern.boottime"))
    return int(time.time() - int(m.group(1))) if m else None


def gpu():
    # Apple silicon: IOAccelerator PerformanceStatistics is readable without root.
    # No temperature sensor without sudo powermetrics; memory is unified.
    out = run(["/usr/sbin/ioreg", "-r", "-d", "1", "-c", "IOAccelerator"])
    m = re.search(r'"Device Utilization %"=(\d+)', out)
    if not m:
        return None
    return {"util_pct": float(m.group(1)), "temp_c": None,
            "note": "memory is unified; see mem.*"}


def services():
    out = {}
    # ps truncates comm= to 16 chars, so match on the basename of args[0].
    ps = run(["/bin/ps", "-axo", "args="])
    for name, (comm, arg) in PROCESSES.items():
        found = False
        for line in ps.splitlines():
            parts = line.split()
            if parts and parts[0].rsplit("/", 1)[-1] == comm and (arg is None or arg in parts[1:]):
                found = True
                break
        out[name] = "active" if found else "inactive"
    for name, port in PORTS.items():
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=1):
                out["port_" + name] = "open"
        except OSError:
            out["port_" + name] = "closed"
    return out


def build_status():
    load1, load5, load15 = [round(x, 2) for x in __import__("os").getloadavg()]
    du = shutil.disk_usage("/")
    return {
        "host": HOST,
        "time": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "uptime_s": uptime_s(),
        "load": {"1m": load1, "5m": load5, "15m": load15},
        "cpu_pct": cpu_percent(),
        "pressure": None,  # no PSI on macOS
        "mem": meminfo(),
        "disk_root": {"used_pct": round(100 * du.used / du.total, 1),
                      "free_gb": round(du.free / 2**30, 1)},
        "gpu": gpu(),
        "services": services(),
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):  # quiet
        pass

    def do_GET(self):
        if self.path == "/healthz":
            body, code, ctype = b"ok\n", 200, "text/plain"
        elif self.path in ("/", "/status"):
            try:
                body = (json.dumps(build_status(), indent=1) + "\n").encode()
                code, ctype = 200, "application/json"
            except Exception as e:
                body = json.dumps({"error": str(e)}).encode()
                code, ctype = 500, "application/json"
        else:
            body, code, ctype = b"not found\n", 404, "text/plain"
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def tailscale_ip():
    for m in re.finditer(r"inet (100\.(?:6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.\d+\.\d+)", run(["/sbin/ifconfig"])):
        return m.group(1)
    return None


def serve(addr):
    ThreadingHTTPServer((addr, PORT), Handler).serve_forever()


if __name__ == "__main__":
    threading.Thread(target=serve, args=("127.0.0.1",), daemon=True).start()
    while True:  # wait for Tailscale after boot; re-bind if the address changes
        ip = tailscale_ip()
        if ip:
            try:
                serve(ip)
            except OSError:
                pass
        time.sleep(5)
