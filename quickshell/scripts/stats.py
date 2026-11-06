#!/usr/bin/env python3
"""Statistiche per il dock Quickshell.

Un'esecuzione ogni ~2s. Mantiene i contatori precedenti in un file di
stato per calcolare CPU e rete come delta (non medie dall'avvio).
Output: una riga JSON.
"""
import json
import os
import pathlib
import subprocess
import time

STATE = pathlib.Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "qs_stats.json"
APPS = ("steam", "obs64")


def run(cmd, timeout=2):
    try:
        return subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout
        ).stdout
    except Exception:
        return ""


def meminfo():
    info = {}
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                k, v = line.split(":", 1)
                info[k.strip()] = int(v.strip().split()[0])
    except Exception:
        return None

    total = info.get("MemTotal", 0)
    avail = info.get("MemAvailable", info.get("MemFree", 0))
    if total <= 0:
        return None
    used = total - avail
    return used / 1048576, total / 1048576, used / total * 100


def cpu_times():
    try:
        with open("/proc/stat") as f:
            parts = f.readline().split()
        vals = list(map(int, parts[1:]))
        idle = vals[3] + (vals[4] if len(vals) > 4 else 0)  # idle + iowait
        return idle, sum(vals)
    except Exception:
        return None


def net_counters():
    rx = tx = 0
    try:
        with open("/proc/net/dev") as f:
            for line in f.readlines()[2:]:
                name, data = line.split(":", 1)
                if name.strip() == "lo":
                    continue
                fields = data.split()
                rx += int(fields[0])
                tx += int(fields[8])
    except Exception:
        return None
    return rx, tx


def volume():
    out = run(["wpctl", "get-volume", "@DEFAULT_SINK@"])
    for line in out.splitlines():
        if "Volume:" in line:
            val = line.split("Volume:")[1].strip()
            num = val.split("[")[0].strip()
            try:
                return int(float(num) * 100)
            except Exception:
                pass
    return None


def wifi():
    out = run(["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL", "dev", "wifi"])
    for line in out.splitlines():
        first = line.split(":", 1)
        if len(first) < 2 or first[0] != "yes":
            continue
        rest = first[1].rsplit(":", 1)
        if len(rest) < 2:
            continue
        ssid = rest[0].replace("\\:", ":")
        try:
            sig = int(rest[1])
        except ValueError:
            sig = 0
        return ssid, sig
    return "", 0


def running_apps():
    procs = {l.strip() for l in run(["ps", "-eo", "comm="]).splitlines() if l.strip()}
    return [a for a in APPS if a in procs]


def main():
    prev = {}
    try:
        prev = json.loads(STATE.read_text())
    except Exception:
        pass

    now = time.monotonic()
    mem = meminfo()

    cpu = None
    ct = cpu_times()
    if ct and "cpu_idle" in prev and "cpu_total" in prev:
        didle = ct[0] - prev["cpu_idle"]
        dtotal = ct[1] - prev["cpu_total"]
        if dtotal > 0:
            cpu = max(0.0, min(100.0, (1 - didle / dtotal) * 100))

    net = net_counters()
    down = up = None
    if net and "net_rx" in prev and "net_t" in prev:
        dt = now - prev["net_t"]
        if dt > 0:
            down = max(0.0, (net[0] - prev["net_rx"]) / dt / 1e6)
            up = max(0.0, (net[1] - prev["net_tx"]) / dt / 1e6)

    ssid, sig = wifi()

    out = {
        "ram_used": round(mem[0], 1) if mem else None,
        "ram_total": round(mem[1], 1) if mem else None,
        "ram_pct": round(mem[2], 1) if mem else None,
        "cpu": round(cpu, 1) if cpu is not None else None,
        "net_down": down,
        "net_up": up,
        "vol": volume(),
        "wifi_ssid": ssid,
        "wifi_signal": sig,
        "apps": running_apps(),
    }

    state = dict(prev)
    if ct:
        state["cpu_idle"], state["cpu_total"] = ct
    if net:
        state["net_rx"], state["net_tx"], state["net_t"] = net[0], net[1], now
    try:
        STATE.write_text(json.dumps(state))
    except Exception:
        pass

    print(json.dumps(out))


if __name__ == "__main__":
    main()
