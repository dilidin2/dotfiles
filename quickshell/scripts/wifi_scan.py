#!/usr/bin/env python3
"""Scan Wi-Fi per il pannello Quickshell (stesso pattern di stats.py).

Output JSON su stdout:
  {"current": {"ssid": "...", "signal": 80} | null,
   "networks": [{"ssid","signal","security","saved"}, ...]}  (per segnale desc)
"""
import subprocess
import json


def nmcli(*fields_args):
    try:
        r = subprocess.run(
            ["nmcli", "-t", "-f", *fields_args],
            capture_output=True, text=True, timeout=8)
        return r.stdout
    except Exception:
        return ""


# ── connessione corrente ─────────────────────────────────────────────
cur = None
out = nmcli("ACTIVE,SSID,SIGNAL", "dev", "wifi")
for line in out.splitlines():
    parts = line.split(":")
    if len(parts) >= 3 and parts[0] == "yes":
        sig = parts[2].strip()
        cur = {"ssid": parts[1].strip(),
               "signal": int(sig) if sig.lstrip("-").isdigit() else 0}
        break

# ── connessioni salvate (per sapere se serve la password) ────────────
saved = set()
out = nmcli("UUID,SSID", "connection", "show")
for line in out.splitlines():
    parts = line.split(":")
    if len(parts) >= 2 and parts[1].strip():
        saved.add(parts[1].strip())

# ── scan ─────────────────────────────────────────────────────────────
nets = {}
out = nmcli("SSID,SIGNAL,SECURITY", "dev", "wifi", "list")
for line in out.splitlines():
    parts = line.split(":")
    if len(parts) < 3:
        continue
    ssid = parts[0].strip()
    if not ssid:
        continue
    sigs = parts[1].strip()
    sig = int(sigs) if sigs.lstrip("-").isdigit() else 0
    sec = parts[2].strip()
    if ssid in nets:
        if sig > nets[ssid]["signal"]:
            nets[ssid]["signal"] = sig
            nets[ssid]["security"] = sec
    else:
        nets[ssid] = {"ssid": ssid, "signal": sig, "security": sec,
                      "saved": ssid in saved}

# La rete a cui sei connesso NON va nella lista (è già in cima, corrente).
if cur:
    nets.pop(cur["ssid"], None)

networks = sorted(nets.values(), key=lambda n: -n["signal"])

print(json.dumps({"current": cur, "networks": networks}))
